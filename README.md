CAHIER DES CHARGES TECHNIQUE

CONCEPTION ET DÉVELOPPEMENT D'UNE INFRASTRUCTURE CLOUD MICROservices SONATHIX GROUP

Projet : SONATHIX CLOUD INFRASTRUCTURE
Application principale : THIX HUB
Entreprise : SONATHIX GROUP
Version : 1.0
Date : Novembre 2026

---

1. PRÉSENTATION DU PROJET

SONATHIX GROUP souhaite concevoir et déployer sa propre infrastructure Cloud permettant d'héberger, d'administrer et de faire évoluer ses différentes solutions numériques.

L'objectif est de mettre en place une architecture microservices distribuée, sécurisée, évolutive et interconnectée, permettant à chaque application ou module de fonctionner de manière autonome tout en communiquant avec les autres services de l'écosystème.

Cette infrastructure devra notamment permettre de réduire la dépendance aux fournisseurs Cloud tiers, de maîtriser les coûts opérationnels, de renforcer la sécurité et de garantir la propriété technique des données et des services.

THIX HUB constituera le premier projet déployé sur cette infrastructure.

2. OBJECTIFS GÉNÉRAUX

Le système devra permettre :

1. La création et l'administration de bases de données indépendantes.
2. Le déploiement de microservices indépendants.
3. L'interconnexion des différents services à travers des API.
4. La centralisation de l'identité des utilisateurs via THIX ID.
5. La gestion centralisée des accès et des permissions.
6. Le stockage sécurisé des fichiers, images et vidéos.
7. La communication en temps réel entre les différents modules.
8. La gestion des sauvegardes et de la restauration des données.
9. La surveillance des performances et de la disponibilité.
10. L'évolution de l'infrastructure sans interruption majeure des applications.

3. ARCHITECTURE TECHNIQUE

L'infrastructure devra reposer sur une architecture microservices avec des composants indépendants.

3.1. Infrastructure serveur

Environnement recommandé :

- VPS Cloud ou serveurs dédiés.
- Ubuntu Server LTS.
- Docker Engine.
- Docker Compose pour le déploiement initial.
- Coolify pour la gestion des applications et déploiements.
- Nginx, Traefik ou Kong pour le routage des services.
- Configuration DNS et certificats SSL/TLS.

L'architecture devra permettre l'ajout ultérieur de plusieurs serveurs et la répartition des services sur différentes machines.

3.2. Système de gestion des bases de données

Technologies envisagées :

PostgreSQL

- Base de données relationnelle principale.
- Gestion des utilisateurs, publications, transactions et relations.
- Gestion des contraintes et transactions.
- Isolation des données par service.

MongoDB (optionnel)

- Gestion de données documentaires.
- Données semi-structurées lorsque cela est justifié.
- Ne devra pas dupliquer inutilement les fonctionnalités de PostgreSQL.

Redis

- Cache.
- Sessions temporaires.
- Files d'attente et traitements rapides.
- Gestion de données temporaires.

Chaque microservice devra être propriétaire de ses données. Aucun service ne devra modifier directement les tables internes d'un autre service.

3.3. Stockage des fichiers

L'infrastructure devra intégrer un système de stockage compatible S3 permettant de gérer :

- Photos de profil.
- Publications.
- Images.
- Vidéos.
- Documents administratifs.
- Pièces jointes.
- Fichiers liés aux événements.

Le stockage devra disposer de mécanismes de contrôle d'accès, de sauvegarde, de limitation de taille et de gestion des fichiers.

4. ARCHITECTURE DES MICROSERVICES

L'écosystème devra être organisé en services métiers indépendants.

4.1. THIX AUTH SERVICE

Service central d'authentification et d'identité.

Fonctionnalités :

- Création des comptes.
- Connexion et déconnexion.
- Gestion des sessions.
- Gestion des mots de passe.
- Vérification des comptes.
- Gestion des rôles et permissions.
- Authentification OAuth2/OIDC.
- Gestion de THIX ID.
- Gestion des accès entre applications.

4.2. THIX SOCIAL SERVICE

Gestion du réseau social.

Fonctionnalités :

- Publications.
- Commentaires.
- Réactions.
- Abonnements.
- Gestion des profils.
- Partages.
- Fil d'actualité.
- Communautés.

4.3. THIX CHAT SERVICE

Gestion des communications.

Fonctionnalités :

- Messagerie privée.
- Conversations de groupe.
- Messages texte.
- Notes vocales.
- Partage de fichiers.
- Accusés de réception.
- Statut de présence.
- Appels audio et vidéo via une infrastructure adaptée.
- Communication en temps réel.

4.4. THIX MARKET SERVICE

Gestion du commerce électronique.

Fonctionnalités :

- Gestion des boutiques.
- Catalogue de produits.
- Gestion des commandes.
- Gestion des vendeurs.
- Suivi des livraisons.
- Gestion des stocks.
- Gestion des transactions commerciales.

4.5. THIX WALLET SERVICE

Gestion des opérations financières.

Fonctionnalités :

- Intégration des fournisseurs de paiement.
- Gestion des demandes de paiement.
- Historique des opérations.
- Vérification des transactions.
- Gestion des remboursements.
- Journalisation des opérations.
- Gestion des notifications financières.

Ce service devra disposer d'un niveau de sécurité renforcé, d'une traçabilité complète et de mécanismes empêchant les doubles transactions.

4.6. THIX MEDIA SERVICE

Gestion des contenus multimédias.

Fonctionnalités :

- Téléversement des fichiers.
- Gestion des photos et vidéos.
- Traitement et compression.
- Gestion des formats.
- Diffusion des contenus.
- Gestion des accès aux médias.

4.7. THIX NOTIFICATION SERVICE

Gestion centralisée des notifications.

Fonctionnalités :

- Notifications push.
- Notifications internes.
- Notifications liées aux transactions.
- Notifications de messages.
- Notifications événementielles.
- Gestion des préférences utilisateur.

4.8. THIX WED / EVENT SERVICE

Gestion des mariages et événements.

Fonctionnalités :

- Création des événements.
- Invitations numériques.
- Gestion des invités.
- Confirmation de présence.
- Gestion des menus.
- Notifications.
- Partage des photos.
- Gestion des informations événementielles.

Les autres modules de THIX HUB devront pouvoir être ajoutés progressivement selon la même architecture.

5. INTERCONNEXION DES SERVICES

L'interconnexion constitue une exigence fondamentale.

Les microservices devront communiquer à travers :

API REST
Pour les échanges directs de données et les opérations synchrones.

Message Broker
RabbitMQ ou technologie équivalente pour la communication asynchrone et la transmission d'événements.

WebSocket
Pour les communications en temps réel.

API Gateway
Pour centraliser les points d'entrée, le routage, les contrôles d'accès et la limitation des requêtes.

Exemple de fonctionnement :

Lorsqu'un utilisateur effectue une commande sur THIX MARKET :

1. THIX AUTH vérifie son identité.
2. THIX MARKET enregistre la commande.
3. THIX WALLET reçoit une demande de paiement si nécessaire.
4. Le fournisseur de paiement confirme le résultat.
5. THIX MARKET actualise le statut de la commande.
6. THIX NOTIFICATION informe l'utilisateur.

Chaque service devra rester autonome et communiquer par des interfaces documentées.

6. GESTION CENTRALISÉE DES UTILISATEURS

THIX ID devra constituer l'identifiant commun de l'écosystème.

Un utilisateur devra pouvoir accéder aux différents modules avec un seul compte.

Le système devra prévoir :

- Identifiant utilisateur unique.
- Gestion centralisée de l'authentification.
- Jetons d'accès sécurisés.
- Gestion des permissions.
- Gestion des sessions.
- Révocation des accès.
- Gestion des appareils connectés.
- Journalisation des connexions.

Les services devront vérifier les droits d'accès sans avoir à créer leurs propres comptes utilisateurs indépendants.

7. SÉCURITÉ ET PROTECTION DES DONNÉES

Le système devra respecter les exigences suivantes :

- Chiffrement des communications avec HTTPS/TLS.
- Gestion sécurisée des secrets et clés API.
- Protection contre les injections SQL.
- Protection contre les attaques par force brute.
- Contrôle des accès par rôles et permissions.
- Séparation des environnements de développement et de production.
- Journalisation des activités sensibles.
- Protection contre les accès non autorisés.
- Rotation des clés et identifiants sensibles.
- Politique de sauvegarde et restauration.
- Gestion des vulnérabilités et mises à jour.

Les bases de données ne devront pas être exposées directement à Internet.

Les services financiers devront bénéficier de contrôles supplémentaires et d'une séparation stricte des responsabilités.

8. SAUVEGARDE ET REPRISE APRÈS SINISTRE

L'infrastructure devra intégrer :

- Sauvegardes automatiques des bases de données.
- Sauvegardes des fichiers multimédias.
- Stockage externe indépendant.
- Chiffrement des sauvegardes.
- Historique des sauvegardes.
- Procédures de restauration.
- Tests périodiques de restauration.
- Documentation du plan de reprise après sinistre.

L'objectif est de pouvoir restaurer les données et les services même en cas de panne majeure, de compromission ou de perte du serveur principal.

9. MONITORING ET ADMINISTRATION

Une interface d'administration devra permettre de surveiller l'ensemble de l'infrastructure.

Outils envisagés :

- Prometheus : collecte des métriques.
- Grafana : tableaux de bord.
- Loki : centralisation des journaux.
- Alertmanager : alertes techniques.

L'administration devra permettre de surveiller :

- État des serveurs.
- Utilisation CPU et RAM.
- Capacité des disques.
- Disponibilité des bases de données.
- État des microservices.
- Nombre de requêtes.
- Temps de réponse des API.
- Erreurs et incidents.
- État des sauvegardes.

10. DÉPLOIEMENT ET GESTION DES VERSIONS

Le système devra intégrer un processus de déploiement continu (CI/CD).

Fonctionnalités attendues :

- Connexion avec GitHub.
- Déploiement automatique après validation.
- Gestion des versions.
- Retour à une version précédente.
- Variables d'environnement sécurisées.
- Gestion des environnements de test et de production.
- Tests automatisés.
- Documentation des déploiements.

Les déploiements d'un service ne devront pas obliger à redéployer tous les autres services.

11. EXIGENCES DE PERFORMANCE ET D'ÉVOLUTIVITÉ

L'architecture devra permettre :

- L'ajout de nouveaux microservices.
- L'augmentation des ressources serveur.
- Le déplacement indépendant des services.
- La répartition des charges.
- La mise en place de plusieurs instances d'un même service.
- La réplication des bases de données.
- L'évolution vers une infrastructure multi-serveurs.
- La réduction des interruptions lors des mises à jour.

Les objectifs de disponibilité, de temps de réponse et de reprise après incident devront être définis et validés lors de la phase de conception détaillée.

12. TECHNOLOGIES RECOMMANDÉES

Domaine| Technologie
Système serveur| Ubuntu Server LTS
Conteneurisation| Docker
Déploiement initial| Docker Compose
Administration| Coolify
Backend| NestJS / Go
Base principale| PostgreSQL
Base documentaire| MongoDB (optionnel)
Cache| Redis
Communication asynchrone| RabbitMQ
API Gateway| Kong / Traefik
Temps réel| WebSocket
Stockage| S3 compatible
Monitoring| Prometheus + Grafana
Logs| Loki
CI/CD| GitHub Actions

Les technologies définitives devront être validées par l'équipe technique avant leur déploiement.

13. PLAN DE RÉALISATION

PHASE 1 : CONCEPTION ET PRÉPARATION

- Étude de l'architecture.
- Choix des fournisseurs Cloud.
- Définition des ressources serveur.
- Conception des bases de données.
- Définition des protocoles de communication.
- Définition des règles de sécurité.

PHASE 2 : INFRASTRUCTURE DE BASE

- Installation d'Ubuntu.
- Installation de Docker.
- Configuration de Coolify.
- Installation de PostgreSQL.
- Installation de Redis.
- Configuration du stockage.
- Mise en place de l'API Gateway.

PHASE 3 : DÉVELOPPEMENT DES SERVICES CENTRAUX

- THIX AUTH.
- THIX API Gateway.
- THIX Notification.
- Système de communication interservices.
- Système de journalisation.

PHASE 4 : DÉVELOPPEMENT DES SERVICES MÉTIERS

- THIX SOCIAL.
- THIX CHAT.
- THIX MARKET.
- THIX WALLET.
- THIX MEDIA.
- THIX WED.

PHASE 5 : SÉCURITÉ ET TESTS

- Tests de charge.
- Tests de sécurité.
- Tests d'intégration.
- Tests de restauration.
- Tests de communication interservices.
- Tests de résistance aux pannes.

PHASE 6 : MIGRATION ET MISE EN PRODUCTION

- Migration progressive depuis Supabase.
- Vérification de l'intégrité des données.
- Tests avec l'application THIX HUB.
- Déploiement progressif.
- Surveillance après mise en production.

14. LIVRABLES ATTENDUS

À la fin du projet, SONATHIX GROUP devra disposer de :

1. Une infrastructure Cloud opérationnelle.
2. Une architecture microservices documentée.
3. Un système centralisé d'authentification.
4. Des bases de données indépendantes.
5. Une API Gateway opérationnelle.
6. Un système de communication interservices.
7. Une infrastructure de stockage.
8. Un système de sauvegarde et restauration.
9. Un système de monitoring.
10. Un système CI/CD.
11. Une documentation technique complète.
12. Une procédure de maintenance et d'exploitation.
13. Une procédure de migration et de retour arrière.

15. CRITÈRES DE VALIDATION

Le projet sera considéré comme techniquement validé lorsque :

- Les microservices pourront fonctionner indépendamment.
- Les services pourront communiquer correctement.
- L'identité THIX ID sera reconnue dans les différents modules.
- Les permissions seront appliquées correctement.
- Une panne d'un service non critique ne provoquera pas l'arrêt de tout l'écosystème.
- Les données pourront être sauvegardées et restaurées.
- Les déploiements pourront être effectués indépendamment.
- Les performances et la sécurité auront été testées.
- THIX HUB pourra communiquer avec la nouvelle infrastructure.

16. VISION À LONG TERME

SONATHIX GROUP souhaite disposer de sa propre infrastructure technologique capable d'accueillir plusieurs produits numériques, au-delà de THIX HUB.

Cette infrastructure devra être conçue comme un socle technologique réutilisable, évolutif et indépendant, pouvant accueillir de nouvelles applications, de nouveaux services et de nouveaux partenaires.

VISION : Construire une infrastructure numérique propriétaire, interconnectée, sécurisée et évolutive, au service de l'écosystème SONATHIX GROUP.

---

FIN DU CAHIER DES CHARGES

Document de cadrage technique – SONATHIX GROUP – Version 1.0
