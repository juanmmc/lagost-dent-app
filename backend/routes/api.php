<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\PatientAuthController;
use App\Http\Controllers\Api\Auth\DoctorAuthController;
use App\Http\Controllers\Api\PatientController;
use App\Http\Controllers\Api\DoctorController;
use App\Http\Controllers\Api\AppointmentController;
use App\Http\Controllers\Api\AttachmentController;

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
        Route::get('/patients/{id}', [PatientController::class, 'show']);
        Route::get('/patients/{id}/diagnoses', [PatientController::class, 'diagnoses']);
        Route::get('/patients/{id}/associates', [PatientController::class, 'associates']);
        Route::get('/patients/{id}/appointments', [AppointmentController::class, 'listForPatient']);

        // Appointments from patient
        Route::post('/appointments', [AppointmentController::class, 'schedule']);
        Route::post('/appointments/by-titular', [AppointmentController::class, 'scheduleByTitular']);
    });

    // Shared appointment detail (any of patient or doctor)
    Route::middleware('ability:patient,doctor')->group(function () {
        Route::get('/patients/{id}/allergies', [PatientController::class, 'allergies']);
        Route::get('/appointments/{id}', [AppointmentController::class, 'show']);
        // Attachments upload allowed by both for now
        Route::post('/attachments', [AttachmentController::class, 'upload']);
    });

    // Doctor context (requires doctor ability)
    Route::middleware('abilities:doctor')->group(function () {
        Route::get('/patients/search', [PatientController::class, 'search']);
        Route::post('/patients/{id}/allergies', [PatientController::class, 'addAllergy']);
        Route::get('/appointments', [AppointmentController::class, 'listForDoctor']);
        Route::post('/appointments/by-doctor', [AppointmentController::class, 'scheduleByDoctor']);
        Route::patch('/appointments/{id}/reschedule', [AppointmentController::class, 'reschedule']);
        Route::patch('/appointments/{id}/confirm', [AppointmentController::class, 'confirm']);
        Route::patch('/appointments/{id}/reject', [AppointmentController::class, 'reject']);
        Route::patch('/appointments/{id}/attend', [AppointmentController::class, 'attend']);
        Route::patch('/appointments/{id}/absent', [AppointmentController::class, 'absent']);
    });
});
