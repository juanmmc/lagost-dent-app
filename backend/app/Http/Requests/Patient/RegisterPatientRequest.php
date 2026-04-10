<?php

namespace App\Http\Requests\Patient;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterPatientRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'phone' => ['required','string','max:32', Rule::unique('people', 'phone')],
            'name' => ['required','string','max:255'],
            'birthdate' => ['required','date'],
            'titular_patient_id' => ['nullable','uuid'],
        ];
    }

    public function messages(): array
    {
        return [
            'phone.unique' => 'El número de celular ya está registrado.',
        ];
    }
}
