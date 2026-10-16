<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\OtpMail;
use App\Models\EmailOtp;
use App\Models\Rider;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class EmailOtpController extends Controller
{
    public function send(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:255'],
        ]);
        $email = Str::lower(trim($validated['email']));

        if (Rider::query()->where('email', $email)->exists()) {
            throw ValidationException::withMessages([
                'email' => 'An account with this email address already exists.',
            ]);
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        EmailOtp::query()->where('email', $email)->delete();
        $otp = EmailOtp::query()->create([
            'email' => $email,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(10),
            'created_at' => now(),
        ]);

        try {
            Mail::to($email)->send(new OtpMail($code));
        } catch (Throwable $exception) {
            $otp->delete();

            throw $exception;
        }

        return response()->json([
            'message' => 'A verification code has been sent.',
        ]);
    }

    public function verify(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'code' => ['required', 'digits:6'],
        ]);
        $email = Str::lower(trim($validated['email']));

        $result = DB::transaction(function () use ($email, $validated): array {
            $otp = EmailOtp::query()
                ->where('email', $email)
                ->latest('id')
                ->lockForUpdate()
                ->first();

            if ($otp === null || $otp->verified_at !== null || $otp->expires_at->isPast()) {
                return ['message' => 'This code is invalid or has expired.'];
            }

            if ($otp->attempts >= 5) {
                return ['message' => 'Too many incorrect attempts. Request a new code.'];
            }

            if (! Hash::check($validated['code'], $otp->code_hash)) {
                $otp->increment('attempts');

                return ['message' => 'This code is invalid or has expired.'];
            }

            $token = bin2hex(random_bytes(32));
            $otp->update([
                'verified_at' => now(),
                'verification_token_hash' => hash('sha256', $token),
                'verification_expires_at' => now()->addMinutes(30),
            ]);

            return ['token' => $token];
        });

        if (! isset($result['token'])) {
            throw ValidationException::withMessages([
                'code' => $result['message'],
            ]);
        }

        return response()->json([
            'verificationToken' => $result['token'],
        ]);
    }
}
