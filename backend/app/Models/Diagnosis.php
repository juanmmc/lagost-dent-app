<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Appointment;
use App\Models\Patient;
use App\Models\Doctor;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class Diagnosis extends Model
{
    use HasUuids;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['appointment_id', 'patient_id', 'doctor_id', 'description'];

    public function appointment()
    {
        return $this->belongsTo(Appointment::class);
    }

    public function patient()
    {
        return $this->belongsTo(Patient::class);
    }

    public function doctor()
    {
        return $this->belongsTo(Doctor::class);
    }
}
