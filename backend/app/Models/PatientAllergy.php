<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use App\Models\Patient;

class PatientAllergy extends Model
{
    use HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['patient_id', 'name', 'severity', 'notes'];

    public function patient()
    {
        return $this->belongsTo(Patient::class);
    }
}
