<?php

namespace Tests\Feature;

use App\Models\EmailOtp;
use App\Models\Rider;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RiderRegistrationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_verified_rider_can_submit_an_application_with_private_documents(): void
    {
        Storage::fake('local');
        $token = str_repeat('a', 64);
        $otp = EmailOtp::query()->create([
            'email' => 'rider@example.com',
            'code_hash' => Hash::make('123456'),
            'expires_at' => now()->addMinutes(10),
            'verified_at' => now(),
            'verification_token_hash' => hash('sha256', $token),
            'verification_expires_at' => now()->addMinutes(30),
            'created_at' => now(),
        ]);

        $response = $this->post('/api/riders/register', [
            'first_name' => 'Juan',
            'last_name' => 'Dela Cruz',
            'birth_date' => '1995-03-12',
            'mobile' => '9123456789',
            'email' => 'rider@example.com',
            'password' => 'secure-password',
            'province_code' => 'NCR',
            'province_name' => 'Metro Manila (NCR)',
            'city_code' => '137404000',
            'city_name' => 'Quezon City',
            'barangay_code' => '137404001',
            'barangay_name' => 'Bagong Pag-asa',
            'street' => '123 Example Street',
            'hub_id' => null,
            'vehicle_type' => 'motorcycle',
            'vehicle_model' => 'Honda Click',
            'plate_number' => 'ABC1234',
            'email_verification_token' => $token,
            'license_front' => UploadedFile::fake()->create('front.jpg', 100, 'image/jpeg'),
            'license_back' => UploadedFile::fake()->create('back.jpg', 100, 'image/jpeg'),
            'orcr' => [UploadedFile::fake()->create('orcr.jpg', 100, 'image/jpeg')],
        ]);

        $response->assertCreated()
            ->assertJsonPath('message', 'Your rider application has been submitted for review.')
            ->assertJsonPath('rider.status', 'pending_review');

        $rider = Rider::query()->where('email', 'rider@example.com')->firstOrFail();
        $this->assertDatabaseHas('riders', [
            'id' => $rider->id,
            'mobile' => '9123456789',
            'status' => 'pending_review',
        ]);
        $this->assertCount(3, $rider->documents);
        $this->assertTrue(Hash::check('secure-password', $rider->password_hash));
        $this->assertNotNull($otp->fresh()->consumed_at);

        foreach ($rider->documents as $document) {
            Storage::disk('local')->assertExists($document->storage_path);
        }
    }

    public function test_registration_rejects_expired_or_unverified_email_tokens(): void
    {
        Storage::fake('local');
        $token = str_repeat('b', 64);
        EmailOtp::query()->create([
            'email' => 'rider@example.com',
            'code_hash' => Hash::make('123456'),
            'expires_at' => now()->addMinutes(10),
            'verified_at' => now(),
            'verification_token_hash' => hash('sha256', $token),
            'verification_expires_at' => now()->subSecond(),
            'created_at' => now(),
        ]);

        $this->post('/api/riders/register', $this->registrationPayload($token))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email_verification_token');

        $this->assertDatabaseCount('riders', 0);
        $this->assertDatabaseCount('rider_documents', 0);
    }

    public function test_registration_token_cannot_be_reused(): void
    {
        Storage::fake('local');
        $token = str_repeat('c', 64);
        EmailOtp::query()->create([
            'email' => 'rider@example.com',
            'code_hash' => Hash::make('123456'),
            'expires_at' => now()->addMinutes(10),
            'verified_at' => now(),
            'verification_token_hash' => hash('sha256', $token),
            'verification_expires_at' => now()->addMinutes(30),
            'consumed_at' => now(),
            'created_at' => now(),
        ]);

        $this->post('/api/riders/register', $this->registrationPayload($token))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email_verification_token');

        $this->assertDatabaseCount('riders', 0);
    }

    /**
     * @return array<string, mixed>
     */
    private function registrationPayload(string $token): array
    {
        return [
            'first_name' => 'Juan',
            'last_name' => 'Dela Cruz',
            'birth_date' => '1995-03-12',
            'mobile' => '9123456789',
            'email' => 'rider@example.com',
            'password' => 'secure-password',
            'province_code' => 'NCR',
            'province_name' => 'Metro Manila (NCR)',
            'city_code' => '137404000',
            'city_name' => 'Quezon City',
            'barangay_code' => '137404001',
            'barangay_name' => 'Bagong Pag-asa',
            'street' => '123 Example Street',
            'vehicle_type' => 'motorcycle',
            'vehicle_model' => 'Honda Click',
            'email_verification_token' => $token,
            'license_front' => UploadedFile::fake()->create('front.jpg', 100, 'image/jpeg'),
            'license_back' => UploadedFile::fake()->create('back.jpg', 100, 'image/jpeg'),
            'orcr' => [UploadedFile::fake()->create('orcr.jpg', 100, 'image/jpeg')],
        ];
    }
}
