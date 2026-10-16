<?php
namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class OtpMail extends Mailable
{
    use SerializesModels;

    public function __construct(public readonly string $code) {}

    public function build(): static
    {
        return $this->subject('Your Pickrush verification code')
            ->html(
                '<p style="font-family:sans-serif">Your 6-digit verification code is:</p>'
                . '<h2 style="font-family:monospace;letter-spacing:8px;font-size:32px">' . $this->code . '</h2>'
                . '<p style="font-family:sans-serif;color:#888">Expires in 10 minutes. Never share this code.</p>'
            );
    }
}
