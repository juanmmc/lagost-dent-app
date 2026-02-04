<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class Attachment extends Model
{
    use HasUuids;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['path', 'type', 'mime', 'size', 'disk'];
}
