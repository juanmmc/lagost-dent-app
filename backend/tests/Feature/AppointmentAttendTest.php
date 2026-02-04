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

class AppointmentAttendTest extends TestCase
{
    use RefreshDatabase;

    private function createDoctorAndPatient(): array
    {
        $doctorPerson = Person::create(['phone' => '940000010', 'name' => 'Dr Attend']);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        $patientPerson = Person::create(['phone' => '940000011', 'name' => 'Paciente Attend']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1995-06-06']);

        return [$doctorPerson, $doctor, $patientPerson, $patient];
    }

    public function test_doctor_attend_with_diagnosis_and_optional_recipe(): void
    {
        [$doctorPerson, $doctor, , $patient] = $this->createDoctorAndPatient();

        $appt = Appointment::create([
            'scheduled_by_person_id' => $doctorPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(2)->setTime(10, 0, 0),
            'status' => AppointmentStatus::Confirmed,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $response = $this->patchJson("/api/appointments/{$appt->id}/attend", [
            'diagnosis_text' => 'Caries tratadas',
            // optional recipe_attachment_id omitted
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('status', AppointmentStatus::Attended->value)
            ->assertJsonPath('diagnosis', 'Caries tratadas');
    }

    public function test_attend_requires_diagnosis_text(): void
    {
        [$doctorPerson, $doctor, , $patient] = $this->createDoctorAndPatient();

        $appt = Appointment::create([
            'scheduled_by_person_id' => $doctorPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => Carbon::now()->addDays(2)->setTime(11, 0, 0),
            'status' => AppointmentStatus::Confirmed,
        ]);

        Sanctum::actingAs($doctorPerson, ['doctor']);

        $response = $this->patchJson("/api/appointments/{$appt->id}/attend", [
            // missing diagnosis_text
        ]);

        $response->assertStatus(422);
    }
}
