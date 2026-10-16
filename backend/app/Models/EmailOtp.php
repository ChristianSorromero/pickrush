<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmailOtp extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'email',
        'code_hash',
        'attempts',
        'expires_at',
        'verified_at',
        'verification_token_hash',
        'verification_expires_at',
        'consumed_at',
        'created_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'verified_at' => 'datetime',
        'verification_expires_at' => 'datetime',
        'consumed_at' => 'datetime',
        'created_at' => 'datetime',
    ];
}
