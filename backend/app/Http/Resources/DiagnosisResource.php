<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class DiagnosisResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'description' => $this->description,
            'doctor' => [
                'id' => $this->doctor->id,
                'name' => $this->doctor->person->name ?? null,
            ],
            'created_at' => $this->created_at,
        ];
    }
}
