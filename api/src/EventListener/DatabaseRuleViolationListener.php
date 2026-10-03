<?php

namespace App\EventListener;

use Doctrine\DBAL\Exception\DriverException;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Les règles métier vérifiées par PostgreSQL (CHECK, triggers, clés étrangères, unicité) remontent
 * au client en 422 / 409 avec le message de la base, au lieu d'une erreur 500.
 */
#[AsEventListener(event: KernelEvents::EXCEPTION, priority: 10)]
final class DatabaseRuleViolationListener
{
    public function __invoke(ExceptionEvent $event): void
    {
        $exception = $event->getThrowable();
        while (!$exception instanceof DriverException && null !== $exception->getPrevious()) {
            $exception = $exception->getPrevious();
        }
        if (!$exception instanceof DriverException) {
            return;
        }

        $sqlState = (string) $exception->getSQLState();
        $message = $this->extractMessage($exception->getMessage());

        $event->setThrowable(match ($sqlState) {
            '23505' => new ConflictHttpException($message, $exception),                                   // unicité
            '23503', '23502', '23514', '22P02', 'P0001' => new UnprocessableEntityHttpException($message, $exception),
            default => $event->getThrowable(),
        });
    }

    /** "SQLSTATE[23514]: Check violation: 7 ERROR:  Négociation limitée…\nCONTEXT: …" → "Négociation limitée…" */
    private function extractMessage(string $raw): string
    {
        if (preg_match('/ERROR:\s+(.+?)(?:\n|$)/u', $raw, $m)) {
            return trim($m[1]);
        }

        return 'Requête refusée par la base de données.';
    }
}
