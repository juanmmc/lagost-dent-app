<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use App\Models\Patient;
use App\Models\Doctor;
use App\Models\Appointment;
use Laravel\Sanctum\HasApiTokens;

class Person extends Authenticatable
{
    use SoftDeletes, HasUuids, HasApiTokens;

    protected $table = 'people';
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['phone', 'name'];

    public function patient()
    {
        return $this->hasOne(Patient::class, 'person_id');
    }

    public function doctor()
    {
        return $this->hasOne(Doctor::class, 'person_id');
    }

    public function scheduledAppointments()
    {
        return $this->hasMany(Appointment::class, 'scheduled_by_person_id');
    }
}
