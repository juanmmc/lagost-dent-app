<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Appointment\ScheduleAppointmentRequest;
use App\Http\Requests\Appointment\RescheduleAppointmentRequest;
use App\Http\Requests\Appointment\AttendAppointmentRequest;
use App\Http\Requests\Appointment\RejectAppointmentRequest;
use App\Http\Requests\Appointment\DoctorScheduleAppointmentRequest;
use App\Http\Resources\AppointmentResource;
use App\Models\Appointment;
use App\Models\AppointmentReschedule;
use App\Models\PatientRelation;
use App\Enums\AppointmentStatus;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AppointmentController extends Controller
{
    public function listForDoctor(Request $request): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $request->validate([
            'date' => ['required','date'],
            'state' => ['nullable','integer'],
            'doctor_id' => ['nullable','uuid'],
            'order' => ['nullable','in:asc,desc'],
        ]);

        $query = Appointment::with(['doctor.person', 'patient.person'])
            ->whereDate('scheduled_at', $request->input('date'));

        if ($request->filled('state')) {
            $query->where('status', (int)$request->input('state'));
        }
        if ($request->filled('doctor_id')) {
            $query->where('doctor_id', $request->input('doctor_id'));
        }

        $order = $request->input('order', 'desc');
        $appointments = $query->orderBy('scheduled_at', $order)->get();

        return response()->json(AppointmentResource::collection($appointments));
    }

    public function listForPatient(Request $request, string $patientId): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('patient')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $order = $request->input('order', 'desc');
        $appointments = Appointment::with(['doctor.person', 'patient.person'])
            ->where('patient_id', $patientId)
            ->orderBy('scheduled_at', $order)
            ->get();
        return response()->json(AppointmentResource::collection($appointments));
    }

    public function show(string $id): JsonResponse
    {
        // Allowed for both patient and doctor tokens via route middleware
        $appointment = Appointment::with(['doctor.person', 'patient.person'])->findOrFail($id);
        return response()->json(new AppointmentResource($appointment));
    }

    public function schedule(ScheduleAppointmentRequest $request): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('patient')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $data = $request->validated();

        return DB::transaction(function () use ($data, $request) {
            $user = $request->user();
            if (!$user) {
                return response()->json(['message' => 'No autenticado'], 401);
            }
            if (Appointment::where('scheduled_at', $data['scheduled_at'])->exists()) {
                return response()->json(['message' => 'El horario ya está ocupado'], 422);
            }

            $appointment = Appointment::create([
                'scheduled_by_person_id' => $user->id,
                'patient_id' => $data['patient_id'],
                'doctor_id' => $data['doctor_id'],
                'scheduled_at' => $data['scheduled_at'],
                'status' => AppointmentStatus::PendingConfirmation,
                'deposit_slip_attachment_id' => $data['deposit_slip_attachment_id'],
            ]);

            return response()->json(new AppointmentResource($appointment->load(['doctor.person','patient.person'])), 201);
        });
    }

    public function scheduleByTitular(ScheduleAppointmentRequest $request): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('patient')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $data = $request->validated();

        $user = $request->user()->load('patient');
        if (!$user->patient) {
            return response()->json(['message' => 'No autenticado como paciente titular'], 401);
        }

        $relation = PatientRelation::where('titular_patient_id', $user->patient->id)
            ->where('associated_patient_id', $data['patient_id'])
            ->first();
        if (!$relation) {
            return response()->json(['message' => 'El paciente no está asociado al titular'], 422);
        }

        return $this->schedule($request);
    }

    public function scheduleByDoctor(DoctorScheduleAppointmentRequest $request): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $data = $request->validated();

        $user = $request->user()->load('doctor');
        if (!$user->doctor || !$user->doctor->active) {
            return response()->json(['message' => 'Doctor inactivo o no válido'], 403);
        }

        return DB::transaction(function () use ($data, $user) {
            if (Appointment::where('scheduled_at', $data['scheduled_at'])->exists()) {
                return response()->json(['message' => 'El horario ya está ocupado'], 422);
            }

            $appointment = Appointment::create([
                'scheduled_by_person_id' => $user->id,
                'patient_id' => $data['patient_id'],
                'doctor_id' => $user->doctor->id,
                'scheduled_at' => $data['scheduled_at'],
                'status' => AppointmentStatus::Confirmed,
                'confirmed_at' => now(),
                'deposit_slip_attachment_id' => $data['deposit_slip_attachment_id'] ?? null,
            ]);

            return response()->json(new AppointmentResource($appointment->load(['doctor.person','patient.person'])), 201);
        });
    }

    public function reschedule(RescheduleAppointmentRequest $request, string $id): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $appointment = Appointment::findOrFail($id);
        $data = $request->validated();

        return DB::transaction(function () use ($appointment, $data, $request) {
            $user = $request->user();
            if (!$user) {
                return response()->json(['message' => 'No autenticado'], 401);
            }
            if (Appointment::where('scheduled_at', $data['new_scheduled_at'])->where('id', '!=', $appointment->id)->exists()) {
                return response()->json(['message' => 'El nuevo horario ya está ocupado'], 422);
            }

            AppointmentReschedule::create([
                'appointment_id' => $appointment->id,
                'actor_person_id' => $user->id,
                'previous_scheduled_at' => $appointment->scheduled_at,
                'new_scheduled_at' => $data['new_scheduled_at'],
                'reason' => $data['reason'] ?? null,
            ]);

            $appointment->scheduled_at = $data['new_scheduled_at'];
            $appointment->save();

            return response()->json(new AppointmentResource($appointment->fresh()->load(['doctor.person','patient.person'])));
        });
    }

    public function confirm(string $id): JsonResponse
    {
        // doctor ability required via route middleware; add inline check too
        if (!request()->user() || !request()->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $appointment = Appointment::findOrFail($id);
        if ($appointment->status !== AppointmentStatus::PendingConfirmation) {
            return response()->json(['message' => 'Solo citas Por confirmar pueden confirmarse'], 422);
        }
        $appointment->status = AppointmentStatus::Confirmed;
        $appointment->confirmed_at = now();
        $appointment->save();
        return response()->json(new AppointmentResource($appointment));
    }

    public function reject(RejectAppointmentRequest $request, string $id): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $appointment = Appointment::findOrFail($id);
        if ($appointment->status !== AppointmentStatus::PendingConfirmation) {
            return response()->json(['message' => 'Solo citas Por confirmar pueden rechazarse'], 422);
        }
        $appointment->status = AppointmentStatus::Rejected;
        $appointment->rejected_at = now();
        $appointment->rejection_reason = $request->validated()['reason'];
        $appointment->save();
        return response()->json(new AppointmentResource($appointment));
    }

    public function attend(AttendAppointmentRequest $request, string $id): JsonResponse
    {
        if (!$request->user() || !$request->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $appointment = Appointment::findOrFail($id);
        $data = $request->validated();
        $appointment->status = AppointmentStatus::Attended;
        $appointment->attended_at = now();
        $appointment->diagnosis_text = $data['diagnosis_text'];
        if (!empty($data['recipe_attachment_id'])) {
            $appointment->recipe_attachment_id = $data['recipe_attachment_id'];
        }
        $appointment->save();
        return response()->json(new AppointmentResource($appointment));
    }

    public function absent(string $id): JsonResponse
    {
        if (!request()->user() || !request()->user()->tokenCan('doctor')) {
            return response()->json(['message' => 'No autorizado'], 403);
        }
        $appointment = Appointment::findOrFail($id);
        $appointment->status = AppointmentStatus::Absent;
        $appointment->absent_at = now();
        $appointment->save();
        return response()->json(new AppointmentResource($appointment));
    }
}
