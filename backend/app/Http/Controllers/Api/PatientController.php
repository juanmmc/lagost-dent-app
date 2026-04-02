<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Patient\RegisterPatientRequest;
use App\Http\Resources\PatientResource;
use App\Http\Resources\DiagnosisResource;
use App\Http\Requests\Patient\CreatePatientAllergyRequest;
use App\Models\Patient;
use App\Models\PatientRelation;
use App\Models\Person;
use App\Models\Diagnosis;
use App\Models\PatientAllergy;
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

    public function associates(string $id): JsonResponse
    {
        $patient = Patient::with('associates.person')->findOrFail($id);
        $associates = $patient->associates;
        return response()->json(PatientResource::collection($associates));
    }

    public function search(Request $request): JsonResponse
    {
        $request->validate([
            'name' => ['required','string','max:255'],
            'limit' => ['nullable','integer','min:1','max:7'],
        ]);

        $name = $request->input('name');
        $limit = min((int)($request->input('limit', 7)), 7);

        $patients = Patient::with('person')
            ->whereHas('person', function ($q) use ($name) {
                $q->where('name', 'ilike', '%'.$name.'%');
            })
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get();

        return response()->json(PatientResource::collection($patients));
    }

    public function addAllergy(CreatePatientAllergyRequest $request, string $id): JsonResponse
    {
        // doctor ability enforced via routes middleware
        $patient = Patient::findOrFail($id);
        $data = $request->validated();

        $allergy = PatientAllergy::create([
            'patient_id' => $patient->id,
            'name' => $data['name'],
            'severity' => $data['severity'] ?? null,
            'notes' => $data['notes'] ?? null,
        ]);

        return response()->json([
            'id' => $allergy->id,
            'patient_id' => $patient->id,
            'name' => $allergy->name,
            'severity' => $allergy->severity,
            'notes' => $allergy->notes,
        ], 201);
    }
}
