<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\PatientAuthController;
use App\Http\Controllers\Api\Auth\DoctorAuthController;
use App\Http\Controllers\Api\PatientController;
use App\Http\Controllers\Api\DoctorController;
use App\Http\Controllers\Api\AppointmentController;
use App\Http\Controllers\Api\AttachmentController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\PushTestController;

Route::prefix('auth')->group(function () {
    Route::post('/patients/validate', [PatientAuthController::class, 'validatePatient']);
    Route::post('/doctors/validate', [DoctorAuthController::class, 'validateDoctor']);
});

// Public patient registration (no doctor-side register for now)
Route::post('/patients', [PatientController::class, 'register']);
// Public list of active doctors
Route::get('/doctors', [DoctorController::class, 'listActive']);

Route::middleware('auth:sanctum')->group(function () {
    // Patients context (requires patient ability)
    Route::middleware('abilities:patient')->group(function () {
        Route::get('/patients/{id}', [PatientController::class, 'show'])->whereUuid('id');
        Route::get('/patients/{id}/diagnoses', [PatientController::class, 'diagnoses'])->whereUuid('id');
        Route::get('/patients/{id}/associates', [PatientController::class, 'associates'])->whereUuid('id');
        Route::get('/patients/{id}/appointments', [AppointmentController::class, 'listForPatient'])->whereUuid('id');

        // Appointments from patient
        Route::post('/appointments', [AppointmentController::class, 'schedule']);
        Route::post('/appointments/by-titular', [AppointmentController::class, 'scheduleByTitular']);
    });

    // Shared appointment detail (any of patient or doctor)
    Route::middleware('ability:patient,doctor')->group(function () {
        Route::get('/patients/{id}/allergies', [PatientController::class, 'allergies'])->whereUuid('id');
        Route::get('/appointments', [AppointmentController::class, 'list']);
        Route::get('/appointments/availability', [AppointmentController::class, 'availability']);
        Route::get('/appointments/{id}', [AppointmentController::class, 'show'])->whereUuid('id');
        // Attachments upload allowed by both for now
        Route::post('/attachments', [AttachmentController::class, 'upload']);
    });

    // Doctor context (requires doctor ability)
    Route::middleware('abilities:doctor')->group(function () {
        Route::get('/patients/search', [PatientController::class, 'search']);
        Route::post('/patients/{id}/allergies', [PatientController::class, 'addAllergy'])->whereUuid('id');
        // Backward compatibility with clients that call this explicit endpoint.
        Route::get('/appointments/listForDoctor', [AppointmentController::class, 'listForDoctor']);
        Route::post('/appointments/by-doctor', [AppointmentController::class, 'scheduleByDoctor']);
        Route::patch('/appointments/{id}/reschedule', [AppointmentController::class, 'reschedule'])->whereUuid('id');
        Route::patch('/appointments/{id}/confirm', [AppointmentController::class, 'confirm'])->whereUuid('id');
        Route::patch('/appointments/{id}/reject', [AppointmentController::class, 'reject'])->whereUuid('id');
        Route::patch('/appointments/{id}/attend', [AppointmentController::class, 'attend'])->whereUuid('id');
        Route::patch('/appointments/{id}/absent', [AppointmentController::class, 'absent'])->whereUuid('id');
    });

    // Device token management (any authenticated user: patient or doctor)
    Route::post('/device-tokens', [DeviceTokenController::class, 'register']);
    Route::delete('/device-tokens', [DeviceTokenController::class, 'deactivate']);
});

// -------------------------------------------------------------------------
// Push notification test endpoint — REMOVE OR RESTRICT BEFORE PRODUCTION
// -------------------------------------------------------------------------
Route::middleware('auth:sanctum')->post('/push-test', [PushTestController::class, 'send']);
