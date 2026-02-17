<?php

namespace App\Http\Requests\Patient;

use Illuminate\Foundation\Http\FormRequest;

class CreatePatientAllergyRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required','string','max:255'],
            'severity' => ['nullable','string','max:32'],
            'notes' => ['nullable','string','max:1000'],
        ];
    }
}
