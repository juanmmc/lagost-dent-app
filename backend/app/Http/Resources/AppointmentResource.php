<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class AppointmentResource extends JsonResource
{
    public function toArray($request)
    {
        $status = $this->status;

        return [
            'id' => $this->id,
            'scheduled_at' => $this->scheduled_at?->toIso8601String(),
            'status' => $status ? [
                'value' => $status->value,
                'descriptor' => $status->descriptor(),
            ] : null,
            'doctor' => $this->whenLoaded('doctor', function () {
                return [
                    'id' => $this->doctor->id,
                    'name' => $this->doctor->person->name ?? null,
                ];
            }),
            'patient' => $this->whenLoaded('patient', function () {
                return [
                    'id' => $this->patient->id,
                    'name' => $this->patient->person->name ?? null,
                ];
            }),
            'diagnosis' => $this->diagnosis_text,
            'deposit_slip_attachment_id' => $this->deposit_slip_attachment_id,
            'deposit_slip_attachment' => $this->whenLoaded('depositSlip', function () {
                $disk = $this->depositSlip->disk ?: 'public';
                $publicUrl = $disk === 'public' ? asset('storage/'.$this->depositSlip->path) : null;

                return [
                    'id' => $this->depositSlip->id,
                    'path' => $this->depositSlip->path,
                    'type' => $this->depositSlip->type,
                    'mime' => $this->depositSlip->mime,
                    'size' => $this->depositSlip->size,
                    'disk' => $disk,
                    'url' => $publicUrl,
                ];
            }),
            'recipe_attachment_id' => $this->recipe_attachment_id,
            'recipe_attachment' => $this->whenLoaded('recipe', function () {
                $disk = $this->recipe->disk ?: 'public';
                $publicUrl = $disk === 'public' ? asset('storage/'.$this->recipe->path) : null;

                return [
                    'id' => $this->recipe->id,
                    'path' => $this->recipe->path,
                    'type' => $this->recipe->type,
                    'mime' => $this->recipe->mime,
                    'size' => $this->recipe->size,
                    'disk' => $disk,
                    'url' => $publicUrl,
                ];
            }),
            'rejection_reason' => $this->rejection_reason,
        ];
    }
}
