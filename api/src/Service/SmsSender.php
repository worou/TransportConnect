<?php

namespace App\Service;

use Psr\Log\LoggerInterface;

/**
 * Envoi de SMS. À brancher sur le fournisseur retenu (Africa's Talking, Twilio…) :
 * pour l'instant le message est seulement journalisé.
 */
final class SmsSender
{
    public function __construct(private readonly LoggerInterface $logger)
    {
    }

    public function envoyer(string $telephone, string $message): void
    {
        $this->logger->info('SMS non envoyé (aucun fournisseur configuré)', ['telephone' => $telephone]);
    }
}
