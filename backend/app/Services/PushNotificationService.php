<?php

namespace App\Services;

use App\Models\DeviceToken;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Exception\Messaging\NotFound;
use Kreait\Firebase\Exception\Messaging\InvalidMessage;
use Kreait\Firebase\Messaging\AndroidConfig;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Psr\Log\LoggerInterface;

class PushNotificationService
{
    public function __construct(
        private readonly Messaging $messaging,
        private readonly LoggerInterface $logger,
    ) {}

    /**
     * Send a push notification to a single FCM token.
     *
     * @param  array<string, string>  $data  Custom key-value data payload
     */
    public function sendToToken(string $token, string $title, string $body, array $data = []): void
    {
        $message = CloudMessage::withTarget('token', $token)
            ->withNotification(Notification::create($title, $body))
            ->withData(array_map(fn ($v) => (string) $v, $data))
            ->withAndroidConfig(AndroidConfig::fromArray([
                'priority' => 'high',
            ]));

        try {
            $this->messaging->send($message);
        } catch (NotFound $e) {
            // Token no longer valid — deactivate it
            $this->deactivateToken($token);
            $this->logger->info('FCM token deactivated (not found)', ['token_prefix' => substr($token, 0, 10)]);
        } catch (InvalidMessage $e) {
            $this->logger->error('FCM invalid message', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    /**
     * Send a notification to all active tokens of a given user.
     *
     * @param  array<string, string>  $data
     */
    public function sendToUser(string $personId, string $title, string $body, array $data = []): void
    {
        $tokens = DeviceToken::query()
            ->where('person_id', $personId)
            ->where('is_active', true)
            ->pluck('token');

        foreach ($tokens as $token) {
            $this->sendToToken($token, $title, $body, $data);
        }
    }

    private function deactivateToken(string $token): void
    {
        DeviceToken::where('token', $token)->update(['is_active' => false]);
    }
}
