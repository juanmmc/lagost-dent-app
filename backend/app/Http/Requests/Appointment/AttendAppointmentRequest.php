<?php

namespace App\Http\Requests\Appointment;

use Illuminate\Foundation\Http\FormRequest;

class AttendAppointmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'diagnosis_text' => ['required','string'],
            'recipe_attachment_id' => ['nullable','uuid'],
        ];
    }
}
