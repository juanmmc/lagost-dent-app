<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Doctor\ValidateDoctorRequest;
use App\Models\Person;
use Illuminate\Support\Facades\Hash;
use Illuminate\Http\JsonResponse;

class DoctorAuthController extends Controller
{
    public function validateDoctor(ValidateDoctorRequest $request): JsonResponse
    {
        $data = $request->validated();

        $person = Person::where('phone', $data['phone'])->with('doctor')->first();
        if (!$person || !$person->doctor) {
            return response()->json(['message' => 'Doctor no encontrado'], 404);
        }

        $doctor = $person->doctor;
        if (!$doctor->active) {
            return response()->json(['message' => 'Doctor inactivo'], 403);
        }

        if (!Hash::check($data['password'], $doctor->password_hash)) {
            return response()->json(['message' => 'Credenciales inválidas'], 422);
        }

        $token = $person->createToken('doctor-token', ['doctor'])->plainTextToken;

        return response()->json([
            'token' => $token,
            'doctor_id' => $doctor->id,
            'person_id' => $person->id,
        ]);
    }
}
