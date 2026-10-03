<?php

namespace App\State\Auth;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use App\ApiResource\Auth\EnvoiOtp;
use App\ApiResource\Auth\OtpEnvoye;
use App\Entity\OtpCode;
use App\Security\AuthService;
use App\Service\SmsSender;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;

final class EnvoiOtpProcessor implements ProcessorInterface
{
    private const MAX_ENVOIS = 3;
    private const FENETRE = '-15 minutes';

    public function __construct(
        private readonly EntityManagerInterface $em,
        private readonly AuthService $auth,
        private readonly SmsSender $sms,
        #[Autowire('%env(bool:OTP_DEBUG)%')] private readonly bool $otpDebug,
    ) {
    }

    /** @param EnvoiOtp $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): OtpEnvoye
    {
        $envoisRecents = (int) $this->em->createQuery(
            'SELECT COUNT(o.id) FROM App\Entity\OtpCode o WHERE o.telephone = :tel AND o.createdAt > :depuis'
        )
            ->setParameter('tel', $data->telephone)
            ->setParameter('depuis', new \DateTimeImmutable(self::FENETRE), Types::DATETIMETZ_IMMUTABLE)
            ->getSingleScalarResult();

        if ($envoisRecents >= self::MAX_ENVOIS) {
            throw new TooManyRequestsHttpException(900, 'Trop de codes demandés. Réessayez dans 15 minutes.');
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', \STR_PAD_LEFT);
        $otp = new OtpCode($data->telephone, $this->auth->hacherOtp($code));
        $this->em->persist($otp);
        $this->em->flush();

        $this->sms->envoyer($data->telephone, "TransConnect : votre code est $code (valable 5 min).");

        return new OtpEnvoye($otp->id->toRfc4122(), OtpCode::DUREE_VALIDITE, $this->otpDebug ? $code : null);
    }
}
