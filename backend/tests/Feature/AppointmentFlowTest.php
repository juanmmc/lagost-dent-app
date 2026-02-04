<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\Person;
use App\Models\Patient;
use App\Models\Doctor;
use App\Models\Attachment;
use App\Models\Appointment;
use App\Enums\AppointmentStatus;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Illuminate\Support\Carbon;

class AppointmentFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_can_schedule_and_doctor_can_confirm(): void
    {
        // Seed minimal data inline
        $doctorPerson = Person::create(['phone' => '900000010', 'name' => 'Dr Flow']);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        $patientPerson = Person::create(['phone' => '900000011', 'name' => 'Paciente Flow']);
        $patient = Patient::create(['person_id' => $patientPerson->id, 'birthdate' => '1991-02-02']);

        $attachment = Attachment::create([
            'path' => 'attachments/test-deposit.jpg',
            'type' => 'deposit_slip',
            'mime' => 'image/jpeg',
            'size' => 1000,
            'disk' => 'local',
        ]);

        // Auth as patient with ability
        Sanctum::actingAs($patientPerson, ['patient']);

        $scheduledAt = Carbon::now()->addDays(3)->setTime(9, 0, 0)->format('Y-m-d H:i:s');
        $scheduleResponse = $this->postJson('/api/appointments', [
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => $scheduledAt,
            'deposit_slip_attachment_id' => $attachment->id,
        ]);

        $scheduleResponse->assertStatus(201)
            ->assertJsonPath('status', AppointmentStatus::PendingConfirmation->value);

        $appointmentId = $scheduleResponse->json('id');
        $this->assertNotEmpty($appointmentId);

        // Auth as doctor to confirm
        Sanctum::actingAs($doctorPerson, ['doctor']);

        $confirmResponse = $this->patchJson("/api/appointments/{$appointmentId}/confirm");
        $confirmResponse->assertStatus(200)
            ->assertJsonPath('status', AppointmentStatus::Confirmed->value);
    }
}
