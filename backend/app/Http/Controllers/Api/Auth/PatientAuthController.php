<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Patient\ValidatePatientRequest;
use App\Models\Person;
use App\Models\Patient;
use Illuminate\Support\Facades\Hash;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

class PatientAuthController extends Controller
{
    public function validatePatient(ValidatePatientRequest $request): JsonResponse
    {
        $data = $request->validated();

        $person = Person::where('phone', $data['phone'])->first();
        if (!$person || !$person->patient) {
            return response()->json(['message' => 'Paciente no encontrado'], 404);
        }

        $patient = $person->patient;
        $patientDate = optional($patient->birthdate)->format('Y-m-d');
        $inputDate = Carbon::parse($data['birthdate'])->format('Y-m-d');
        if ($patientDate !== $inputDate) {
            return response()->json(['message' => 'Datos inválidos'], 422);
        }

        $token = $person->createToken('patient-token', ['patient'])->plainTextToken;

        return response()->json([
            'token' => $token,
            'patient_id' => $patient->id,
            'person_id' => $person->id,
        ]);
    }
}
