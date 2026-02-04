<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Patient\RegisterPatientRequest;
use App\Http\Resources\PatientResource;
use App\Http\Resources\DiagnosisResource;
use App\Models\Patient;
use App\Models\PatientRelation;
use App\Models\Person;
use App\Models\Diagnosis;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;

class PatientController extends Controller
{
    public function register(RegisterPatientRequest $request): JsonResponse
    {
        $data = $request->validated();

        return DB::transaction(function () use ($data) {
            $person = Person::create([
                'phone' => $data['phone'],
                'name' => $data['name'],
            ]);

            $patient = Patient::create([
                'person_id' => $person->id,
                'birthdate' => $data['birthdate'],
            ]);

            if (!empty($data['titular_patient_id'])) {
                PatientRelation::create([
                    'titular_patient_id' => $data['titular_patient_id'],
                    'associated_patient_id' => $patient->id,
                ]);
            }

            return response()->json(new PatientResource($patient->load('person')), 201);
        });
    }

    public function show(string $id): JsonResponse
    {
        $patient = Patient::with('person')->findOrFail($id);
        return response()->json(new PatientResource($patient));
    }

    public function allergies(string $id): JsonResponse
    {
        $patient = Patient::findOrFail($id);
        $allergies = $patient->hasMany(\App\Models\PatientAllergy::class)->get();
        return response()->json($allergies);
    }

    public function diagnoses(string $id): JsonResponse
    {
        $patient = Patient::findOrFail($id);
        $diagnoses = Diagnosis::with('doctor.person')
            ->where('patient_id', $patient->id)
            ->orderByDesc('created_at')
            ->get();
        return response()->json(DiagnosisResource::collection($diagnoses));
    }
}
