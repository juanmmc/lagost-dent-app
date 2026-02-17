<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Doctor;
use Illuminate\Http\JsonResponse;

class DoctorController extends Controller
{
    public function listActive(): JsonResponse
    {
        $doctors = Doctor::with('person')
            ->where('active', true)
            ->orderBy('created_at', 'desc')
            ->get();

        $data = $doctors->map(function ($doc) {
            return [
                'id' => $doc->id,
                'name' => $doc->person->name ?? null,
                'phone' => $doc->person->phone ?? null,
            ];
        });

        return response()->json($data);
    }
}
