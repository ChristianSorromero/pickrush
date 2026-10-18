<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmailOtp;
use App\Models\Rider;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Throwable;

class RiderRegistrationController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $files = $request->allFiles();
        if (isset($files['orcr[]']) && !isset($files['orcr'])) {
            $files['orcr'] = $files['orcr[]'];
            unset($files['orcr[]']);
            $request->files->replace($files);
        }

        $validated = $request->validate([
            'first_name' => ['required', 'string', 'max:255'],
            'last_name' => ['required', 'string', 'max:255'],
            'birth_date' => ['required', 'date', 'before:today'],
            'mobile' => ['required', 'digits:10', Rule::unique('riders', 'mobile')],
            'email' => ['required', 'email', 'max:255', Rule::unique('riders', 'email')],
            'password' => ['required', 'string', 'min:8', 'max:255'],
            'province_code' => ['required', 'string', 'max:32'],
            'province_name' => ['required', 'string', 'max:255'],
            'city_code' => ['required', 'string', 'max:32'],
            'city_name' => ['required', 'string', 'max:255'],
            'barangay_code' => ['required', 'string', 'max:32'],
            'barangay_name' => ['required', 'string', 'max:255'],
            'street' => ['required', 'string', 'max:1000'],
            'hub_id' => ['nullable', Rule::exists('hubs', 'id')->where('is_active', true)],
            'vehicle_type' => ['required', Rule::in(['motorcycle', 'car', 'tricycle', 'bicycle_other'])],
            'plate_number' => ['nullable', 'string', 'max:32'],
            'email_verification_token' => ['required', 'string', 'size:64'],
            'license_front' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
            'license_back' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
            'orcr' => ['required', 'array', 'min:1', 'max:5'],
            'orcr.*' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
        ]);
        $email = mb_strtolower(trim($validated['email']));
        $tokenHash = hash('sha256', $validated['email_verification_token']);
        $documents = [
            ['type' => 'license_front', 'file' => $validated['license_front']],
            ['type' => 'license_back', 'file' => $validated['license_back']],
        ];

        foreach ($validated['orcr'] as $file) {
            $documents[] = ['type' => 'orcr', 'file' => $file];
        }

        $storedPaths = [];

        try {
            $rider = DB::transaction(function () use (
                $validated,
                $email,
                $tokenHash,
                $documents,
                &$storedPaths,
            ): Rider {
                $otp = EmailOtp::query()
                    ->where('email', $email)
                    ->where('verification_token_hash', $tokenHash)
                    ->lockForUpdate()
                    ->first();

                if (
                    $otp === null
                    || $otp->verified_at === null
                    || $otp->consumed_at !== null
                    || $otp->verification_expires_at === null
                    || $otp->verification_expires_at->isPast()
                ) {
                    throw ValidationException::withMessages([
                        'email_verification_token' => 'Email verification has expired. Please verify your email again.',
                    ]);
                }

                $rider = Rider::query()->create([
                    'first_name' => $validated['first_name'],
                    'last_name' => $validated['last_name'],
                    'birth_date' => $validated['birth_date'],
                    'mobile' => $validated['mobile'],
                    'email' => $email,
                    'password_hash' => Hash::make($validated['password']),
                    'province_code' => $validated['province_code'],
                    'province_name' => $validated['province_name'],
                    'city_code' => $validated['city_code'],
                    'city_name' => $validated['city_name'],
                    'barangay_code' => $validated['barangay_code'],
                    'barangay_name' => $validated['barangay_name'],
                    'street' => $validated['street'],
                    'hub_id' => $validated['hub_id'] ?? null,
                    'vehicle_type' => $validated['vehicle_type'],
                    'plate_number' => $validated['plate_number'] ?? null,
                    'submitted_at' => now(),
                ]);

                foreach ($documents as $document) {
                    /** @var UploadedFile $file */
                    $file = $document['file'];
                    $path = $file->store("rider-documents/{$rider->id}", 'local');

                    if ($path === false) {
                        throw new RuntimeException('A rider document could not be stored.');
                    }

                    $storedPaths[] = $path;
                    $rider->documents()->create([
                        'doc_type' => $document['type'],
                        'storage_path' => $path,
                        'mime_type' => $file->getMimeType() ?? 'application/octet-stream',
                        'uploaded_at' => now(),
                    ]);
                }

                $otp->update(['consumed_at' => now()]);

                return $rider;
            });
        } catch (Throwable $exception) {
            if ($storedPaths !== []) {
                Storage::disk('local')->delete($storedPaths);
            }

            throw $exception;
        }

        $rider->refresh();

        return response()->json([
            'message' => 'Your rider application has been submitted for review.',
            'rider' => [
                'id' => $rider->id,
                'status' => $rider->status,
            ],
        ], 201);
    }
}
