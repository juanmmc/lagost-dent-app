<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Patient;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class PatientRelation extends Model
{
    use HasUuids;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['titular_patient_id', 'associated_patient_id', 'relation_type'];

    public function titular()
    {
        return $this->belongsTo(Patient::class, 'titular_patient_id');
    }

    public function associated()
    {
        return $this->belongsTo(Patient::class, 'associated_patient_id');
    }
}
