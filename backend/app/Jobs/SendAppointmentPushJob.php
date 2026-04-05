<?php

namespace App\Jobs;

use App\Services\PushNotificationService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class SendAppointmentPushJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;
    public int $backoff = 10;

    /**
     * @param  array<string, string>  $data  Custom key-value payload for Android
     */
    public function __construct(
        private readonly string $recipientPersonId,
        private readonly string $title,
        private readonly string $body,
        private readonly array  $data = [],
    ) {}

    public function handle(PushNotificationService $push): void
    {
        $push->sendToUser($this->recipientPersonId, $this->title, $this->body, $this->data);
    }
}
