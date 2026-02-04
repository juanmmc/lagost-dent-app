<?php

namespace App\Http\Requests\Appointment;

use Illuminate\Foundation\Http\FormRequest;

class ScheduleAppointmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'patient_id' => ['required','uuid'],
            'doctor_id' => ['required','uuid'],
            'scheduled_at' => ['required','date_format:Y-m-d H:i:s'],
            'deposit_slip_attachment_id' => ['required','uuid'],
        ];
    }
}
