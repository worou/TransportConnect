<?php

namespace App\Controller;

use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Uid\Uuid;

/**
 * Envoi d'une photo (évaluation, demande, livraison) : multipart, champ « fichier ».
 * Renvoie l'URL publique, à utiliser ensuite dans POST /api/photos. Réservé aux utilisateurs connectés
 * (access_control ^/api/).
 */
final class UploadController
{
    private const TYPES = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    private const TAILLE_MAX = 5 * 1024 * 1024;

    public function __construct(
        #[Autowire('%env(resolve:UPLOAD_DIR)%')] private readonly string $dossier,
        #[Autowire('%env(UPLOAD_BASE_URL)%')] private readonly string $urlBase,
    ) {
    }

    #[Route('/api/uploads', name: 'api_upload', methods: ['POST'])]
    public function __invoke(Request $request): JsonResponse
    {
        $fichier = $request->files->get('fichier');
        if (!$fichier instanceof UploadedFile || !$fichier->isValid()) {
            throw new UnprocessableEntityHttpException('Fichier manquant ou trop volumineux (champ « fichier »).');
        }
        $type = $fichier->getMimeType();
        if (!isset(self::TYPES[$type])) {
            throw new UnprocessableEntityHttpException('Format accepté : JPEG, PNG ou WebP.');
        }
        if ($fichier->getSize() > self::TAILLE_MAX) {
            throw new UnprocessableEntityHttpException('Image trop volumineuse (5 Mo maximum).');
        }

        // Nom imprévisible, rangé par mois ; l'extension vient du type réel, jamais du nom envoyé
        $sousDossier = date('Y-m');
        $nom = Uuid::v4()->toRfc4122().'.'.self::TYPES[$type];
        $fichier->move($this->dossier.'/'.$sousDossier, $nom);

        return new JsonResponse(['url' => rtrim($this->urlBase, '/').'/'.$sousDossier.'/'.$nom], 201);
    }
}
