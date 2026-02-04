<?php

namespace App\Http\Requests\Patient;

use Illuminate\Foundation\Http\FormRequest;

class RegisterPatientRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'phone' => ['required','string','max:32'],
            'name' => ['required','string','max:255'],
            'birthdate' => ['required','date'],
            'titular_patient_id' => ['nullable','uuid'],
        ];
    }
}
