<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Appointment;
use App\Models\Person;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class AppointmentReschedule extends Model
{
    use HasUuids;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'appointment_id',
        'actor_person_id',
        'previous_scheduled_at',
        'new_scheduled_at',
        'reason',
    ];

    protected $casts = [
        'previous_scheduled_at' => 'datetime',
        'new_scheduled_at' => 'datetime',
    ];

    public function appointment()
    {
        return $this->belongsTo(Appointment::class);
    }

    public function actor()
    {
        return $this->belongsTo(Person::class, 'actor_person_id');
    }
}
