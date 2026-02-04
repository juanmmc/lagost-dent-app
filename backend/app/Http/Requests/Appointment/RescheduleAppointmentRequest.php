<?php

namespace App\Http\Requests\Appointment;

use Illuminate\Foundation\Http\FormRequest;

class RescheduleAppointmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'new_scheduled_at' => ['required','date_format:Y-m-d H:i:s'],
            'reason' => ['nullable','string','max:1000'],
        ];
    }
}
