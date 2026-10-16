<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Hub extends Model
{
    public $incrementing = false;
    protected $keyType   = 'string';
    protected $fillable  = ['id', 'name', 'province', 'is_active'];
}
