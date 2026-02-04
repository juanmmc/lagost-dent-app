<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use App\Models\Person;
use App\Models\Appointment;

class Doctor extends Model
{
    use SoftDeletes, HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['person_id', 'password_hash', 'active'];

    protected $hidden = ['password_hash'];

    public function person()
    {
        return $this->belongsTo(Person::class, 'person_id');
    }

    public function appointments()
    {
        return $this->hasMany(Appointment::class);
    }
}
