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

class AppointmentAbsentTest extends TestCase
{
    use RefreshDatabase;

    public function test_doctor_marks_appointment_as_absent(): void
    {
        $doctorPerson = Person::create(['phone' => '950000010', 'name' => 'Dr Absent']);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        $patientPerson = Person::create(['phone' => '950000011', 'name' => 'Paciente Absent']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1996-07-07']);

        $appt = Appointment::create([
            'scheduled_by_person_id' => $doctorPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(1)->setTime(10, 0, 0),
            'status' => AppointmentStatus::Confirmed,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $response = $this->patchJson("/api/appointments/{$appt->id}/absent");
        $response->assertStatus(200)
            ->assertJsonPath('status', AppointmentStatus::Absent->value);
    }
}
