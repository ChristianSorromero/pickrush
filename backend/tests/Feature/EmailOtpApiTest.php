<?php

namespace Tests\Feature;

use App\Mail\OtpMail;
use App\Models\EmailOtp;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class EmailOtpApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_email_otp_can_be_sent_and_verified_once(): void
    {
        Mail::fake();

        $this->postJson('/api/auth/email-otp/send', [
            'email' => 'Rider@example.com',
        ])->assertOk()
            ->assertJsonPath('message', 'A verification code has been sent.');

        $code = null;
        Mail::assertSent(OtpMail::class, function (OtpMail $mail) use (&$code): bool {
            $code = $mail->code;

            return true;
        });
        $this->assertIsString($code);

        $response = $this->postJson('/api/auth/email-otp/verify', [
            'email' => 'rider@example.com',
            'code' => $code,
        ]);

        $response->assertOk()->assertJsonStructure(['verificationToken']);
        $otp = EmailOtp::query()->firstOrFail();
        $this->assertNotNull($otp->verified_at);
        $this->assertNotNull($otp->verification_token_hash);
        $this->assertSame('rider@example.com', $otp->email);
    }

    public function test_incorrect_codes_are_limited_and_do_not_verify_the_email(): void
    {
        Mail::fake();

        $this->postJson('/api/auth/email-otp/send', [
            'email' => 'rider@example.com',
        ])->assertOk();

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/auth/email-otp/verify', [
                'email' => 'rider@example.com',
                'code' => '000000',
            ])->assertUnprocessable();
        }

        $otp = EmailOtp::query()->firstOrFail();
        $this->assertSame(5, $otp->attempts);
        $this->assertNull($otp->verified_at);
        $this->assertNull($otp->verification_token_hash);
    }

    public function test_expired_codes_are_rejected(): void
    {
        $otp = EmailOtp::query()->create([
            'email' => 'rider@example.com',
            'code_hash' => Hash::make('123456'),
            'expires_at' => now()->subSecond(),
            'created_at' => now()->subMinutes(11),
        ]);

        $this->postJson('/api/auth/email-otp/verify', [
            'email' => $otp->email,
            'code' => '123456',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('code');
    }
}
