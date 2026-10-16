<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

class Rider extends Authenticatable
{
    use HasApiTokens;

    public $incrementing = false;

    protected $keyType = 'string';

    protected $hidden = ['password_hash'];

    protected $fillable = [
        'first_name', 'last_name', 'birth_date', 'mobile', 'email', 'password_hash',
        'province_code', 'province_name', 'city_code', 'city_name',
        'barangay_code', 'barangay_name', 'street', 'hub_id',
        'vehicle_type', 'vehicle_model', 'plate_number', 'submitted_at',
    ];

    protected static function boot(): void
    {
        parent::boot();
        static::creating(fn ($m) => $m->id = (string) Str::uuid());
    }

    public function getAuthPassword(): string
    {
        return $this->password_hash;
    }

    public function documents(): HasMany
    {
        return $this->hasMany(RiderDocument::class);
    }
}
