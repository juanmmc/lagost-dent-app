<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use App\Enums\AppointmentStatus;
use App\Models\Patient;
use App\Models\Doctor;
use App\Models\Person;
use App\Models\Attachment;

class Appointment extends Model
{
    use SoftDeletes, HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $casts = [
        'status' => AppointmentStatus::class,
        'scheduled_at' => 'datetime',
        'confirmed_at' => 'datetime',
        'attended_at' => 'datetime',
        'absent_at' => 'datetime',
        'rejected_at' => 'datetime',
    ];

    protected $fillable = [
        'scheduled_by_person_id',
        'patient_id',
        'doctor_id',
        'scheduled_at',
        'status',
        'diagnosis_text',
        'deposit_slip_attachment_id',
        'recipe_attachment_id',
        'confirmed_at',
        'attended_at',
        'absent_at',
        'rejected_at',
        'rejection_reason',
    ];

    public function patient()
    {
        return $this->belongsTo(Patient::class);
    }

    public function doctor()
    {
        return $this->belongsTo(Doctor::class);
    }

    public function scheduler()
    {
        return $this->belongsTo(Person::class, 'scheduled_by_person_id');
    }

    public function depositSlip()
    {
        return $this->belongsTo(Attachment::class, 'deposit_slip_attachment_id');
    }

    public function recipe()
    {
        return $this->belongsTo(Attachment::class, 'recipe_attachment_id');
    }
}
