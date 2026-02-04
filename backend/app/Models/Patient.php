<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use App\Models\Person;
use App\Models\Appointment;

class Patient extends Model
{
    use SoftDeletes, HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['person_id', 'birthdate'];

    protected $casts = [
        'birthdate' => 'date',
    ];

    public function person()
    {
        return $this->belongsTo(Person::class, 'person_id');
    }

    public function associates()
    {
        return $this->belongsToMany(Patient::class, 'patient_relations', 'titular_patient_id', 'associated_patient_id');
    }

    public function titular()
    {
        return $this->belongsToMany(Patient::class, 'patient_relations', 'associated_patient_id', 'titular_patient_id');
    }

    public function appointments()
    {
        return $this->hasMany(Appointment::class);
    }
}
