<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\Person;
use App\Models\Patient;
use App\Models\Doctor;
use App\Models\Appointment;
use App\Enums\AppointmentStatus;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Illuminate\Support\Carbon;

class AppointmentRejectTest extends TestCase
{
    use RefreshDatabase;

    public function test_doctor_can_reject_pending_confirmation_with_reason(): void
    {
        $doctorPerson = Person::create(['phone' => '920000010', 'name' => 'Dr Reject']);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        $patientPerson = Person::create(['phone' => '920000011', 'name' => 'Paciente Reject']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1993-04-04']);

        $appt = Appointment::create([
            'scheduled_by_person_id' => $patientPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(5)->setTime(10, 0, 0),
            'status' => AppointmentStatus::PendingConfirmation,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $response = $this->patchJson("/api/appointments/{$appt->id}/reject", [
            'reason' => 'Pago no verificado',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('status', AppointmentStatus::Rejected->value)
            ->assertJsonPath('rejection_reason', 'Pago no verificado');
    }

    public function test_reject_non_pending_returns_422(): void
    {
        $doctorPerson = Person::create(['phone' => '920000012', 'name' => 'Dr Reject 422']);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        $patientPerson = Person::create(['phone' => '920000013', 'name' => 'Paciente Reject 422']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1993-04-04']);

        $appt = Appointment::create([
            'scheduled_by_person_id' => $patientPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(6)->setTime(11, 0, 0),
            'status' => AppointmentStatus::Confirmed,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $response = $this->patchJson("/api/appointments/{$appt->id}/reject", [
            'reason' => 'Motivo',
        ]);

        $response->assertStatus(422)
            ->assertJson(['message' => 'Solo citas Por confirmar pueden rechazarse']);
    }
}
