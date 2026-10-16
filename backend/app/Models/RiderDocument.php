<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RiderDocument extends Model
{
    public $timestamps  = false;
    protected $fillable = ['rider_id','doc_type','storage_path','mime_type','uploaded_at'];
    protected $casts    = ['uploaded_at' => 'datetime'];
}
