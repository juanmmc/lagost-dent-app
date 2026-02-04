<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class PatientResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'name' => $this->person->name ?? null,
            'phone' => $this->person->phone ?? null,
            'birthdate' => $this->birthdate?->format('Y-m-d'),
        ];
    }
}
