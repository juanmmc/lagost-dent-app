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

class AppointmentListFilterTest extends TestCase
{
    use RefreshDatabase;

    public function test_doctor_can_list_by_date_and_filter_state_and_doctor(): void
    {
        // Doctors
        $doctorPersonA = Person::create(['phone' => '930000010', 'name' => 'Dr A']);
        $doctorA = Doctor::create([
            'person_id' => $doctorPersonA->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);
        $doctorPersonB = Person::create(['phone' => '930000011', 'name' => 'Dr B']);
        $doctorB = Doctor::create([
            'person_id' => $doctorPersonB->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        // Patient
        $patientPerson = Person::create(['phone' => '930000012', 'name' => 'Paciente List']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1994-05-05']);

        $date = Carbon::now()->addDays(8)->format('Y-m-d');

        // Two appts on same date, different status and doctor
        $apptConfirmed = Appointment::create([
            'scheduled_by_person_id' => $patientPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctorA->id,
            'scheduled_at' => Carbon::parse($date.' 09:00:00'),
            'status' => AppointmentStatus::Confirmed,
        ]);

        $apptPending = Appointment::create([
            'scheduled_by_person_id' => $patientPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctorB->id,
            'scheduled_at' => Carbon::parse($date.' 10:00:00'),
            'status' => AppointmentStatus::PendingConfirmation,
        ]);

        // One appt on different date (should not be included)
        Appointment::create([
            'scheduled_by_person_id' => $patientPerson->id,
            'patient_id' => $patient->id,
            'doctor_id' => $doctorA->id,
            'scheduled_at' => Carbon::now()->addDays(9)->setTime(9, 0, 0),
            'status' => AppointmentStatus::Confirmed,
        ]);

        Sanctum::actingAs($doctorPersonA, ['doctor']);

        // Filter by date + status Confirmed + doctor A
        $response = $this->getJson("/api/appointments?date={$date}&state=".AppointmentStatus::Confirmed->value."&doctor_id={$doctorA->id}&order=desc");
        $response->assertStatus(200);

        $data = $response->json();
        $this->assertCount(1, $data);
        $this->assertEquals($apptConfirmed->id, $data[0]['id']);
        $this->assertEquals(AppointmentStatus::Confirmed->value, $data[0]['status']);
    }
}
