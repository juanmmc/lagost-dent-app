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

class AppointmentRescheduleTest extends TestCase
{
    use RefreshDatabase;

    private function makeDoctor(): array
    {
        $doctorPerson = Person::create(['phone' => '910000010', 'name' => 'Dr Reschedule']);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);
        return [$doctorPerson, $doctor];
    }

    private function makePatient(): array
    {
        $patientPerson = Person::create(['phone' => '910000011', 'name' => 'Paciente Reschedule']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1992-03-03']);
        return [$patientPerson, $patient];
    }

    public function test_doctor_can_reschedule_appointment(): void
    {
        [$doctorPerson, $doctor] = $this->makeDoctor();
        [, $patient] = $this->makePatient();

        $appt = Appointment::create([
            'scheduled_by_person_id' => $doctorPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(1)->setTime(10, 0, 0),
            'status' => AppointmentStatus::PendingConfirmation,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $newTime = Carbon::now()->addDays(2)->setTime(11, 0, 0)->format('Y-m-d H:i:s');
        $response = $this->patchJson("/api/appointments/{$appt->id}/reschedule", [
            'new_scheduled_at' => $newTime,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('scheduled_at', Carbon::parse($newTime)->toIso8601String());
    }

    public function test_reschedule_conflict_is_rejected(): void
    {
        [$doctorPerson, $doctor] = $this->makeDoctor();
        [, $patient] = $this->makePatient();

        $slot = Carbon::now()->addDays(3)->setTime(12, 0, 0);

        $apptA = Appointment::create([
            'scheduled_by_person_id' => $doctorPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => $slot,
            'status' => AppointmentStatus::PendingConfirmation,
        ]);

        $apptB = Appointment::create([
            'scheduled_by_person_id' => $doctorPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(4)->setTime(13, 0, 0),
            'status' => AppointmentStatus::PendingConfirmation,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $response = $this->patchJson("/api/appointments/{$apptB->id}/reschedule", [
            'new_scheduled_at' => $slot->format('Y-m-d H:i:s'),
        ]);

        $response->assertStatus(422)
            ->assertJson(['message' => 'El nuevo horario ya está ocupado']);
    }
}
