export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      addresses: {
        Row: {
          address_line: string
          city: string
          created_at: string | null
          full_name: string
          id: string
          is_default: boolean | null
          latitude: number | null
          longitude: number | null
          phone: string
          postal_code: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          address_line: string
          city: string
          created_at?: string | null
          full_name: string
          id?: string
          is_default?: boolean | null
          latitude?: number | null
          longitude?: number | null
          phone: string
          postal_code?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          address_line?: string
          city?: string
          created_at?: string | null
          full_name?: string
          id?: string
          is_default?: boolean | null
          latitude?: number | null
          longitude?: number | null
          phone?: string
          postal_code?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "addresses_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_activities: {
        Row: {
          action: string
          admin_id: string
          created_at: string | null
          id: string
          ip_address: string | null
          metadata: Json | null
          target_id: string
          target_type: string
        }
        Insert: {
          action: string
          admin_id: string
          created_at?: string | null
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          target_id: string
          target_type: string
        }
        Update: {
          action?: string
          admin_id?: string
          created_at?: string | null
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          target_id?: string
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_activities_admin_id_fkey"
            columns: ["admin_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_logs: {
        Row: {
          action: string | null
          admin_id: string
          created_at: string | null
          details: string | null
          id: string
          target: string | null
        }
        Insert: {
          action?: string | null
          admin_id: string
          created_at?: string | null
          details?: string | null
          id?: string
          target?: string | null
        }
        Update: {
          action?: string | null
          admin_id?: string
          created_at?: string | null
          details?: string | null
          id?: string
          target?: string | null
        }
        Relationships: []
      }
      admins: {
        Row: {
          id: string
          role: string | null
        }
        Insert: {
          id: string
          role?: string | null
        }
        Update: {
          id?: string
          role?: string | null
        }
        Relationships: []
      }
      annonces: {
        Row: {
          contact: string | null
          created_at: string | null
          date_expiration: string | null
          date_publication: string | null
          description: string
          devise: string | null
          est_actif: boolean | null
          est_verifie: boolean | null
          id: string
          images_url: string[] | null
          localisation: string | null
          prix: number
          titre: string
          type: string
          updated_at: string | null
          user_id: string | null
          vendeur_avatar: string | null
          vendeur_nom: string | null
        }
        Insert: {
          contact?: string | null
          created_at?: string | null
          date_expiration?: string | null
          date_publication?: string | null
          description: string
          devise?: string | null
          est_actif?: boolean | null
          est_verifie?: boolean | null
          id?: string
          images_url?: string[] | null
          localisation?: string | null
          prix: number
          titre: string
          type: string
          updated_at?: string | null
          user_id?: string | null
          vendeur_avatar?: string | null
          vendeur_nom?: string | null
        }
        Update: {
          contact?: string | null
          created_at?: string | null
          date_expiration?: string | null
          date_publication?: string | null
          description?: string
          devise?: string | null
          est_actif?: boolean | null
          est_verifie?: boolean | null
          id?: string
          images_url?: string[] | null
          localisation?: string | null
          prix?: number
          titre?: string
          type?: string
          updated_at?: string | null
          user_id?: string | null
          vendeur_avatar?: string | null
          vendeur_nom?: string | null
        }
        Relationships: []
      }
      applications: {
        Row: {
          created_at: string | null
          id: string
          job_id: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          job_id?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          job_id?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "applications_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "jobs"
            referencedColumns: ["id"]
          },
        ]
      }
      approvals: {
        Row: {
          created_at: string | null
          id: string
          receiver_id: string | null
          request_type: string | null
          sender_id: string | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          request_type?: string | null
          sender_id?: string | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          request_type?: string | null
          sender_id?: string | null
          status?: string | null
        }
        Relationships: []
      }
      articles: {
        Row: {
          author_name: string | null
          category: string | null
          content: string | null
          created_at: string | null
          id: string
          image_url: string | null
          is_trending: boolean | null
          title: string
        }
        Insert: {
          author_name?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_trending?: boolean | null
          title: string
        }
        Update: {
          author_name?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_trending?: boolean | null
          title?: string
        }
        Relationships: []
      }
      auction_bids: {
        Row: {
          amount: number
          auction_id: string
          created_at: string | null
          id: string
          user_id: string
        }
        Insert: {
          amount: number
          auction_id: string
          created_at?: string | null
          id?: string
          user_id: string
        }
        Update: {
          amount?: number
          auction_id?: string
          created_at?: string | null
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "auction_bids_auction_id_fkey"
            columns: ["auction_id"]
            isOneToOne: false
            referencedRelation: "auctions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "auction_bids_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      auctions: {
        Row: {
          bid_count: number | null
          created_at: string | null
          current_bid: number | null
          end_time: string
          id: string
          live_id: string | null
          product_id: string | null
          starting_price: number
          status: string | null
          updated_at: string | null
        }
        Insert: {
          bid_count?: number | null
          created_at?: string | null
          current_bid?: number | null
          end_time: string
          id?: string
          live_id?: string | null
          product_id?: string | null
          starting_price: number
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          bid_count?: number | null
          created_at?: string | null
          current_bid?: number | null
          end_time?: string
          id?: string
          live_id?: string | null
          product_id?: string | null
          starting_price?: number
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "auctions_live_id_fkey"
            columns: ["live_id"]
            isOneToOne: false
            referencedRelation: "lives"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "auctions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          created_at: string | null
          entity: string | null
          entity_id: string | null
          id: string
          ip_address: string | null
          metadata: Json | null
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          created_at?: string | null
          entity?: string | null
          entity_id?: string | null
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          created_at?: string | null
          entity?: string | null
          entity_id?: string | null
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      beneficiaries: {
        Row: {
          added_at: string
          avatar: string | null
          email: string | null
          id: string
          name: string
          phone: string
          user_id: string
        }
        Insert: {
          added_at?: string
          avatar?: string | null
          email?: string | null
          id?: string
          name: string
          phone: string
          user_id: string
        }
        Update: {
          added_at?: string
          avatar?: string | null
          email?: string | null
          id?: string
          name?: string
          phone?: string
          user_id?: string
        }
        Relationships: []
      }
      beneficiary_accounts: {
        Row: {
          account_holder_name: string | null
          account_number: string
          bank_name: string
          beneficiary_id: string
          created_at: string
          id: string
          is_default: boolean
        }
        Insert: {
          account_holder_name?: string | null
          account_number: string
          bank_name: string
          beneficiary_id: string
          created_at?: string
          id?: string
          is_default?: boolean
        }
        Update: {
          account_holder_name?: string | null
          account_number?: string
          bank_name?: string
          beneficiary_id?: string
          created_at?: string
          id?: string
          is_default?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "beneficiary_accounts_beneficiary_id_fkey"
            columns: ["beneficiary_id"]
            isOneToOne: false
            referencedRelation: "beneficiaries"
            referencedColumns: ["id"]
          },
        ]
      }
      blocked_users: {
        Row: {
          blocked_user_id: string | null
          created_at: string | null
          id: string
          reason: string | null
          user_id: string | null
        }
        Insert: {
          blocked_user_id?: string | null
          created_at?: string | null
          id?: string
          reason?: string | null
          user_id?: string | null
        }
        Update: {
          blocked_user_id?: string | null
          created_at?: string | null
          id?: string
          reason?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "blocked_users_blocked_user_id_fkey"
            columns: ["blocked_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "blocked_users_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      blood_requests: {
        Row: {
          blood_type: string | null
          created_at: string | null
          id: number
          latitude: number | null
          longitude: number | null
          type: string | null
          user_id: string | null
        }
        Insert: {
          blood_type?: string | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
          type?: string | null
          user_id?: string | null
        }
        Update: {
          blood_type?: string | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
          type?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      blood_services: {
        Row: {
          blood_type: string
          created_at: string | null
          id: string
          location: unknown
          service_type: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          blood_type: string
          created_at?: string | null
          id?: string
          location?: unknown
          service_type?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          blood_type?: string
          created_at?: string | null
          id?: string
          location?: unknown
          service_type?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      boost_orders: {
        Row: {
          created_at: string | null
          id: string
          package_id: string
          paid_at: string | null
          price: number
          product_id: string
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          package_id: string
          paid_at?: string | null
          price: number
          product_id: string
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          package_id?: string
          paid_at?: string | null
          price?: number
          product_id?: string
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "boost_orders_package_id_fkey"
            columns: ["package_id"]
            isOneToOne: false
            referencedRelation: "boost_packages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boost_orders_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      boost_packages: {
        Row: {
          created_at: string | null
          duration_days: number
          estimated_views: number | null
          id: string
          is_active: boolean | null
          name: string
          original_price: number | null
          price: number
        }
        Insert: {
          created_at?: string | null
          duration_days: number
          estimated_views?: number | null
          id?: string
          is_active?: boolean | null
          name: string
          original_price?: number | null
          price: number
        }
        Update: {
          created_at?: string | null
          duration_days?: number
          estimated_views?: number | null
          id?: string
          is_active?: boolean | null
          name?: string
          original_price?: number | null
          price?: number
        }
        Relationships: []
      }
      bus: {
        Row: {
          amenities: string[] | null
          arrivee: string
          compagnie: string
          created_at: string | null
          date_depart: string
          depart: string
          devise: string | null
          duree_minutes: number
          est_actif: boolean | null
          heure_arrivee: string
          heure_depart: string
          id: string
          image_url: string | null
          prix: number
          sieges_disponibles: number
          sieges_total: number
        }
        Insert: {
          amenities?: string[] | null
          arrivee: string
          compagnie: string
          created_at?: string | null
          date_depart: string
          depart: string
          devise?: string | null
          duree_minutes: number
          est_actif?: boolean | null
          heure_arrivee: string
          heure_depart: string
          id?: string
          image_url?: string | null
          prix: number
          sieges_disponibles: number
          sieges_total?: number
        }
        Update: {
          amenities?: string[] | null
          arrivee?: string
          compagnie?: string
          created_at?: string | null
          date_depart?: string
          depart?: string
          devise?: string | null
          duree_minutes?: number
          est_actif?: boolean | null
          heure_arrivee?: string
          heure_depart?: string
          id?: string
          image_url?: string | null
          prix?: number
          sieges_disponibles?: number
          sieges_total?: number
        }
        Relationships: []
      }
      call_history: {
        Row: {
          call_type: string | null
          caller_id: string | null
          chat_id: string | null
          created_at: string | null
          duration_seconds: number | null
          ended_at: string | null
          id: string
          kind: string
          receiver_id: string | null
          room_id: string | null
          started_at: string
          status: string | null
          updated_at: string
        }
        Insert: {
          call_type?: string | null
          caller_id?: string | null
          chat_id?: string | null
          created_at?: string | null
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          kind: string
          receiver_id?: string | null
          room_id?: string | null
          started_at?: string
          status?: string | null
          updated_at?: string
        }
        Update: {
          call_type?: string | null
          caller_id?: string | null
          chat_id?: string | null
          created_at?: string | null
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          kind?: string
          receiver_id?: string | null
          room_id?: string | null
          started_at?: string
          status?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "call_history_caller_id_fkey"
            columns: ["caller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "call_history_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      calls: {
        Row: {
          caller_id: string
          channel_id: string | null
          created_at: string | null
          id: string
          receiver_id: string | null
          status: string | null
          type: string | null
        }
        Insert: {
          caller_id: string
          channel_id?: string | null
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          status?: string | null
          type?: string | null
        }
        Update: {
          caller_id?: string
          channel_id?: string | null
          created_at?: string | null
          id?: string
          receiver_id?: string | null
          status?: string | null
          type?: string | null
        }
        Relationships: []
      }
      cart: {
        Row: {
          color: string | null
          created_at: string | null
          id: string
          product_id: string
          quantity: number
          updated_at: string | null
          user_id: string
          variant: string | null
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          id?: string
          product_id: string
          quantity?: number
          updated_at?: string | null
          user_id: string
          variant?: string | null
        }
        Update: {
          color?: string | null
          created_at?: string | null
          id?: string
          product_id?: string
          quantity?: number
          updated_at?: string | null
          user_id?: string
          variant?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cart_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          created_at: string | null
          icon: string | null
          id: string
          name: string
        }
        Insert: {
          created_at?: string | null
          icon?: string | null
          id?: string
          name: string
        }
        Update: {
          created_at?: string | null
          icon?: string | null
          id?: string
          name?: string
        }
        Relationships: []
      }
      certifications: {
        Row: {
          created_at: string | null
          file_url: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          issue_date: string | null
          issuer: string | null
          title: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issuer?: string | null
          title?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issuer?: string | null
          title?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "certifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_messages: {
        Row: {
          content: string
          created_at: string | null
          id: string
          room_id: string | null
          sender_id: string | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          room_id?: string | null
          sender_id?: string | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          room_id?: string | null
          sender_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "chat_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_participants: {
        Row: {
          chat_id: string
          user_id: string
        }
        Insert: {
          chat_id: string
          user_id: string
        }
        Update: {
          chat_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_participants_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "chats"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_rooms: {
        Row: {
          id: string
          last_message: string | null
          participant_a: string | null
          participant_b: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          last_message?: string | null
          participant_a?: string | null
          participant_b?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          last_message?: string | null
          participant_a?: string | null
          participant_b?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_rooms_participant_a_fkey"
            columns: ["participant_a"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_participant_b_fkey"
            columns: ["participant_b"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      chats: {
        Row: {
          chat_id: string
          content: string | null
          created_at: string | null
          id: string
          is_read: boolean | null
          sender_id: string | null
        }
        Insert: {
          chat_id: string
          content?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          sender_id?: string | null
        }
        Update: {
          chat_id?: string
          content?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          sender_id?: string | null
        }
        Relationships: []
      }
      colis: {
        Row: {
          created_at: string | null
          date_envoi: string | null
          date_livraison_estimee: string | null
          destinataire: string
          destinataire_adresse: string
          destinataire_ville: string
          devise: string | null
          expediteur: string
          expediteur_adresse: string
          expediteur_ville: string
          id: string
          mode_livraison: string
          numero_suivi: string
          poids_kg: number
          prix: number
          status: string | null
          type_colis: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          date_envoi?: string | null
          date_livraison_estimee?: string | null
          destinataire: string
          destinataire_adresse: string
          destinataire_ville: string
          devise?: string | null
          expediteur: string
          expediteur_adresse: string
          expediteur_ville: string
          id?: string
          mode_livraison: string
          numero_suivi: string
          poids_kg: number
          prix: number
          status?: string | null
          type_colis: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          date_envoi?: string | null
          date_livraison_estimee?: string | null
          destinataire?: string
          destinataire_adresse?: string
          destinataire_ville?: string
          devise?: string | null
          expediteur?: string
          expediteur_adresse?: string
          expediteur_ville?: string
          id?: string
          mode_livraison?: string
          numero_suivi?: string
          poids_kg?: number
          prix?: number
          status?: string | null
          type_colis?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      colis_historique: {
        Row: {
          colis_id: string
          created_at: string | null
          date_etape: string
          description: string | null
          id: string
          localisation: string
          status: string
        }
        Insert: {
          colis_id: string
          created_at?: string | null
          date_etape?: string
          description?: string | null
          id?: string
          localisation: string
          status: string
        }
        Update: {
          colis_id?: string
          created_at?: string | null
          date_etape?: string
          description?: string | null
          id?: string
          localisation?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "colis_historique_colis_id_fkey"
            columns: ["colis_id"]
            isOneToOne: false
            referencedRelation: "colis"
            referencedColumns: ["id"]
          },
        ]
      }
      comment_likes: {
        Row: {
          comment_id: string | null
          created_at: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          comment_id?: string | null
          created_at?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          comment_id?: string | null
          created_at?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "comment_likes_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          content: string
          created_at: string | null
          id: string
          post_id: string | null
          user_id: string | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      communes: {
        Row: {
          id: string
          name: string
          ville_id: string | null
        }
        Insert: {
          id?: string
          name: string
          ville_id?: string | null
        }
        Update: {
          id?: string
          name?: string
          ville_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "communes_ville_id_fkey"
            columns: ["ville_id"]
            isOneToOne: false
            referencedRelation: "villes"
            referencedColumns: ["id"]
          },
        ]
      }
      communities: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          logo_url: string | null
          members_count: number | null
          name: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          logo_url?: string | null
          members_count?: number | null
          name: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          logo_url?: string | null
          members_count?: number | null
          name?: string
        }
        Relationships: []
      }
      community_members: {
        Row: {
          community_id: string | null
          id: string
          joined_at: string | null
          user_id: string | null
        }
        Insert: {
          community_id?: string | null
          id?: string
          joined_at?: string | null
          user_id?: string | null
        }
        Update: {
          community_id?: string | null
          id?: string
          joined_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "community_members_community_id_fkey"
            columns: ["community_id"]
            isOneToOne: false
            referencedRelation: "communities"
            referencedColumns: ["id"]
          },
        ]
      }
      community_posts: {
        Row: {
          community_id: string | null
          content: string
          created_at: string | null
          id: string
          images: string[] | null
          user_id: string | null
        }
        Insert: {
          community_id?: string | null
          content: string
          created_at?: string | null
          id?: string
          images?: string[] | null
          user_id?: string | null
        }
        Update: {
          community_id?: string | null
          content?: string
          created_at?: string | null
          id?: string
          images?: string[] | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "community_posts_community_id_fkey"
            columns: ["community_id"]
            isOneToOne: false
            referencedRelation: "network_communities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_posts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          industry: string | null
          name: string
          owner_id: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          industry?: string | null
          name: string
          owner_id?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          industry?: string | null
          name?: string
          owner_id?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      company_members: {
        Row: {
          company_id: string | null
          created_at: string | null
          id: string
          role: string | null
          user_id: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "company_members_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      confidential_messages: {
        Row: {
          code_hash: string
          created_at: string | null
          id: string
          is_biometric: boolean | null
          is_opened: boolean | null
          message_id: string
        }
        Insert: {
          code_hash: string
          created_at?: string | null
          id?: string
          is_biometric?: boolean | null
          is_opened?: boolean | null
          message_id: string
        }
        Update: {
          code_hash?: string
          created_at?: string | null
          id?: string
          is_biometric?: boolean | null
          is_opened?: boolean | null
          message_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_confidential_message"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      connection_requests: {
        Row: {
          created_at: string | null
          id: string
          message: string | null
          receiver_id: string | null
          sender_id: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          message?: string | null
          receiver_id?: string | null
          sender_id?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          message?: string | null
          receiver_id?: string | null
          sender_id?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      connections: {
        Row: {
          connection_id: string | null
          created_at: string | null
          id: string
          status: string | null
          user_id: string | null
        }
        Insert: {
          connection_id?: string | null
          created_at?: string | null
          id?: string
          status?: string | null
          user_id?: string | null
        }
        Update: {
          connection_id?: string | null
          created_at?: string | null
          id?: string
          status?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      constants: {
        Row: {
          created_at: string
          date: string
          glycemie: number | null
          heart_rate: number | null
          id: string
          notes: string | null
          patient_id: string
          poids: number | null
          spo2: number | null
          taille: number | null
          temperature: number | null
          tension_diastolic: number | null
          tension_systolic: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          date?: string
          glycemie?: number | null
          heart_rate?: number | null
          id?: string
          notes?: string | null
          patient_id: string
          poids?: number | null
          spo2?: number | null
          taille?: number | null
          temperature?: number | null
          tension_diastolic?: number | null
          tension_systolic?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          date?: string
          glycemie?: number | null
          heart_rate?: number | null
          id?: string
          notes?: string | null
          patient_id?: string
          poids?: number | null
          spo2?: number | null
          taille?: number | null
          temperature?: number | null
          tension_diastolic?: number | null
          tension_systolic?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "constants_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      consultations: {
        Row: {
          created_at: string
          date: string
          diagnostic: string
          doctor_id: string | null
          doctor_name: string
          exam_orders: Json | null
          id: string
          motif: string
          patient_id: string
          patient_name: string
          prescriptions: Json | null
          status: Database["public"]["Enums"]["consultation_status_enum"] | null
          traitement: string | null
          updated_at: string
          vital_signs: Json | null
        }
        Insert: {
          created_at?: string
          date?: string
          diagnostic: string
          doctor_id?: string | null
          doctor_name: string
          exam_orders?: Json | null
          id?: string
          motif: string
          patient_id: string
          patient_name: string
          prescriptions?: Json | null
          status?:
            | Database["public"]["Enums"]["consultation_status_enum"]
            | null
          traitement?: string | null
          updated_at?: string
          vital_signs?: Json | null
        }
        Update: {
          created_at?: string
          date?: string
          diagnostic?: string
          doctor_id?: string | null
          doctor_name?: string
          exam_orders?: Json | null
          id?: string
          motif?: string
          patient_id?: string
          patient_name?: string
          prescriptions?: Json | null
          status?:
            | Database["public"]["Enums"]["consultation_status_enum"]
            | null
          traitement?: string | null
          updated_at?: string
          vital_signs?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "consultations_doctor_id_fkey"
            columns: ["doctor_id"]
            isOneToOne: false
            referencedRelation: "doctors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "consultations_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      contacts_urgence: {
        Row: {
          created_at: string | null
          id: string
          nom: string | null
          relation: string | null
          telephone: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          nom?: string | null
          relation?: string | null
          telephone?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          nom?: string | null
          relation?: string | null
          telephone?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      conversation_participants: {
        Row: {
          conversation_id: string
          id: string
          joined_at: string | null
          user_id: string
        }
        Insert: {
          conversation_id: string
          id?: string
          joined_at?: string | null
          user_id: string
        }
        Update: {
          conversation_id?: string
          id?: string
          joined_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_participants_conversation"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_participants_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          avatar_url: string | null
          created_at: string | null
          id: string
          is_archived: boolean | null
          is_group: boolean | null
          last_message: string | null
          last_message_time: string | null
          metadata: Json | null
          name: string
          participant_ids: string[]
          updated_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string | null
          id?: string
          is_archived?: boolean | null
          is_group?: boolean | null
          last_message?: string | null
          last_message_time?: string | null
          metadata?: Json | null
          name: string
          participant_ids?: string[]
          updated_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string | null
          id?: string
          is_archived?: boolean | null
          is_group?: boolean | null
          last_message?: string | null
          last_message_time?: string | null
          metadata?: Json | null
          name?: string
          participant_ids?: string[]
          updated_at?: string | null
        }
        Relationships: []
      }
      credit_payments: {
        Row: {
          amount: number
          created_at: string
          credit_request_id: string
          due_date: string
          id: string
          paid_at: string | null
          status: string
        }
        Insert: {
          amount: number
          created_at?: string
          credit_request_id: string
          due_date: string
          id?: string
          paid_at?: string | null
          status?: string
        }
        Update: {
          amount?: number
          created_at?: string
          credit_request_id?: string
          due_date?: string
          id?: string
          paid_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "credit_payments_credit_request_id_fkey"
            columns: ["credit_request_id"]
            isOneToOne: false
            referencedRelation: "credit_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      credit_requests: {
        Row: {
          amount: number
          approved_at: string | null
          created_at: string
          duration_months: number
          id: string
          interest_rate: number
          reason: string | null
          rejected_at: string | null
          rejected_reason: string | null
          status: string
          user_id: string
        }
        Insert: {
          amount: number
          approved_at?: string | null
          created_at?: string
          duration_months: number
          id?: string
          interest_rate?: number
          reason?: string | null
          rejected_at?: string | null
          rejected_reason?: string | null
          status?: string
          user_id: string
        }
        Update: {
          amount?: number
          approved_at?: string | null
          created_at?: string
          duration_months?: number
          id?: string
          interest_rate?: number
          reason?: string | null
          rejected_at?: string | null
          rejected_reason?: string | null
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      deleted_messages_for_user: {
        Row: {
          deleted_at: string | null
          id: string
          message_id: string
          user_id: string
        }
        Insert: {
          deleted_at?: string | null
          id?: string
          message_id: string
          user_id: string
        }
        Update: {
          deleted_at?: string | null
          id?: string
          message_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_deleted_message"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_deleted_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_slots: {
        Row: {
          available_count: number | null
          created_at: string | null
          date: string
          end_time: string
          id: string
          start_time: string
        }
        Insert: {
          available_count?: number | null
          created_at?: string | null
          date: string
          end_time: string
          id?: string
          start_time: string
        }
        Update: {
          available_count?: number | null
          created_at?: string | null
          date?: string
          end_time?: string
          id?: string
          start_time?: string
        }
        Relationships: []
      }
      delivery_tracking: {
        Row: {
          dest_latitude: number | null
          dest_longitude: number | null
          driver_id: string | null
          id: string
          order_id: string
          status: string | null
          updated_at: string | null
        }
        Insert: {
          dest_latitude?: number | null
          dest_longitude?: number | null
          driver_id?: string | null
          id?: string
          order_id: string
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          dest_latitude?: number | null
          dest_longitude?: number | null
          driver_id?: string | null
          id?: string
          order_id?: string
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "delivery_tracking_driver_id_fkey"
            columns: ["driver_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_tracking_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      disputes: {
        Row: {
          created_at: string | null
          id: string
          last_message: string | null
          mediator_id: string | null
          order_id: string
          reason: string | null
          status: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          last_message?: string | null
          mediator_id?: string | null
          order_id: string
          reason?: string | null
          status?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          last_message?: string | null
          mediator_id?: string | null
          order_id?: string
          reason?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "disputes_mediator_id_fkey"
            columns: ["mediator_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "disputes_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "disputes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      doctors: {
        Row: {
          created_at: string
          hospital_id: string | null
          id: string
          profile_id: string
          rpps_number: string | null
          services: string[] | null
          specialty: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          hospital_id?: string | null
          id?: string
          profile_id: string
          rpps_number?: string | null
          services?: string[] | null
          specialty: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          hospital_id?: string | null
          id?: string
          profile_id?: string
          rpps_number?: string | null
          services?: string[] | null
          specialty?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "doctors_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      documents: {
        Row: {
          created_at: string | null
          doc_id: string | null
          doc_type: string | null
          document_type: string | null
          file_path: string | null
          file_url: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          mime_type: string | null
          status: string | null
          storage_path: string | null
          title: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          doc_id?: string | null
          doc_type?: string | null
          document_type?: string | null
          file_path?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          mime_type?: string | null
          status?: string | null
          storage_path?: string | null
          title?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          doc_id?: string | null
          doc_type?: string | null
          document_type?: string | null
          file_path?: string | null
          file_url?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          mime_type?: string | null
          status?: string | null
          storage_path?: string | null
          title?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "documents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      drafts: {
        Row: {
          conversation_id: string
          id: string
          metadata: Json | null
          text: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          conversation_id: string
          id?: string
          metadata?: Json | null
          text?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          conversation_id?: string
          id?: string
          metadata?: Json | null
          text?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_drafts_conversation"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_drafts_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      education: {
        Row: {
          city: string | null
          created_at: string | null
          date_debut: string | null
          date_fin: string | null
          degree: string | null
          diploma: string | null
          establishment: string | null
          field_of_study: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          period: string | null
          school_name: string | null
          user_id: string | null
        }
        Insert: {
          city?: string | null
          created_at?: string | null
          date_debut?: string | null
          date_fin?: string | null
          degree?: string | null
          diploma?: string | null
          establishment?: string | null
          field_of_study?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          period?: string | null
          school_name?: string | null
          user_id?: string | null
        }
        Update: {
          city?: string | null
          created_at?: string | null
          date_debut?: string | null
          date_fin?: string | null
          degree?: string | null
          diploma?: string | null
          establishment?: string | null
          field_of_study?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          period?: string | null
          school_name?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "education_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_alerts: {
        Row: {
          audio_record_url: string | null
          created_at: string | null
          id: string
          is_silent: boolean | null
          location_gps: unknown
          status: string | null
          type: string
          user_id: string | null
        }
        Insert: {
          audio_record_url?: string | null
          created_at?: string | null
          id?: string
          is_silent?: boolean | null
          location_gps?: unknown
          status?: string | null
          type: string
          user_id?: string | null
        }
        Update: {
          audio_record_url?: string | null
          created_at?: string | null
          id?: string
          is_silent?: boolean | null
          location_gps?: unknown
          status?: string | null
          type?: string
          user_id?: string | null
        }
        Relationships: []
      }
      emergency_audio_logs: {
        Row: {
          alert_id: number | null
          created_at: string | null
          file_url: string | null
          id: number
        }
        Insert: {
          alert_id?: number | null
          created_at?: string | null
          file_url?: string | null
          id?: number
        }
        Update: {
          alert_id?: number | null
          created_at?: string | null
          file_url?: string | null
          id?: number
        }
        Relationships: []
      }
      emergency_audit_logs: {
        Row: {
          action: string | null
          created_at: string | null
          id: number
          metadata: Json | null
          user_id: string | null
        }
        Insert: {
          action?: string | null
          created_at?: string | null
          id?: number
          metadata?: Json | null
          user_id?: string | null
        }
        Update: {
          action?: string | null
          created_at?: string | null
          id?: number
          metadata?: Json | null
          user_id?: string | null
        }
        Relationships: []
      }
      emergency_contacts: {
        Row: {
          city: string | null
          id: string
          name: string | null
          phone: string | null
          relation: string | null
          user_id: string | null
        }
        Insert: {
          city?: string | null
          id?: string
          name?: string | null
          phone?: string | null
          relation?: string | null
          user_id?: string | null
        }
        Update: {
          city?: string | null
          id?: string
          name?: string | null
          phone?: string | null
          relation?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "emergency_contacts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      emergency_notifications: {
        Row: {
          alert_id: number | null
          created_at: string | null
          id: number
          message: string | null
          recipient_id: string | null
          status: string | null
        }
        Insert: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          message?: string | null
          recipient_id?: string | null
          status?: string | null
        }
        Update: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          message?: string | null
          recipient_id?: string | null
          status?: string | null
        }
        Relationships: []
      }
      emergency_services: {
        Row: {
          id: number
          name: string | null
          phone: string | null
          type: string | null
        }
        Insert: {
          id?: number
          name?: string | null
          phone?: string | null
          type?: string | null
        }
        Update: {
          id?: number
          name?: string | null
          phone?: string | null
          type?: string | null
        }
        Relationships: []
      }
      emergency_tracking: {
        Row: {
          alert_id: number | null
          created_at: string | null
          id: number
          latitude: number | null
          longitude: number | null
        }
        Insert: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
        }
        Update: {
          alert_id?: number | null
          created_at?: string | null
          id?: number
          latitude?: number | null
          longitude?: number | null
        }
        Relationships: []
      }
      ephemeral_messages: {
        Row: {
          created_at: string | null
          duration_seconds: number
          id: string
          message_id: string
          opened_at: string | null
        }
        Insert: {
          created_at?: string | null
          duration_seconds: number
          id?: string
          message_id: string
          opened_at?: string | null
        }
        Update: {
          created_at?: string | null
          duration_seconds?: number
          id?: string
          message_id?: string
          opened_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_ephemeral_message"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      evenements: {
        Row: {
          capacite: number | null
          categorie: string
          created_at: string | null
          date_debut: string
          date_fin: string | null
          description: string | null
          devise: string | null
          est_actif: boolean | null
          est_gratuit: boolean | null
          id: string
          images_url: string[] | null
          lieu: string
          organisateur: string | null
          places_restantes: number | null
          prix: number | null
          titre: string
          updated_at: string | null
          ville: string
        }
        Insert: {
          capacite?: number | null
          categorie: string
          created_at?: string | null
          date_debut: string
          date_fin?: string | null
          description?: string | null
          devise?: string | null
          est_actif?: boolean | null
          est_gratuit?: boolean | null
          id?: string
          images_url?: string[] | null
          lieu: string
          organisateur?: string | null
          places_restantes?: number | null
          prix?: number | null
          titre: string
          updated_at?: string | null
          ville: string
        }
        Update: {
          capacite?: number | null
          categorie?: string
          created_at?: string | null
          date_debut?: string
          date_fin?: string | null
          description?: string | null
          devise?: string | null
          est_actif?: boolean | null
          est_gratuit?: boolean | null
          id?: string
          images_url?: string[] | null
          lieu?: string
          organisateur?: string | null
          places_restantes?: number | null
          prix?: number | null
          titre?: string
          updated_at?: string | null
          ville?: string
        }
        Relationships: []
      }
      event_booking_attempts: {
        Row: {
          attempted_at: string | null
          event_id: string | null
          id: string
          ip_address: string | null
          quantity: number | null
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          attempted_at?: string | null
          event_id?: string | null
          id?: string
          ip_address?: string | null
          quantity?: number | null
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          attempted_at?: string | null
          event_id?: string | null
          id?: string
          ip_address?: string | null
          quantity?: number | null
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_booking_attempts_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_booking_limits: {
        Row: {
          created_at: string | null
          event_id: string
          max_per_person: number | null
          max_per_transaction: number | null
          member_only_limit: number | null
          require_id_verification: boolean | null
          restricted_zones: string[] | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          event_id: string
          max_per_person?: number | null
          max_per_transaction?: number | null
          member_only_limit?: number | null
          require_id_verification?: boolean | null
          restricted_zones?: string[] | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          event_id?: string
          max_per_person?: number | null
          max_per_transaction?: number | null
          member_only_limit?: number | null
          require_id_verification?: boolean | null
          restricted_zones?: string[] | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_booking_limits_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: true
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_bookings: {
        Row: {
          booking_date: string | null
          event_id: string | null
          id: string
          payment_method: string | null
          payment_status: string | null
          qr_code: string | null
          status: string | null
          ticket_code: string | null
          ticket_quantity: number | null
          total_price: number
          used_at: string | null
          user_id: string | null
        }
        Insert: {
          booking_date?: string | null
          event_id?: string | null
          id?: string
          payment_method?: string | null
          payment_status?: string | null
          qr_code?: string | null
          status?: string | null
          ticket_code?: string | null
          ticket_quantity?: number | null
          total_price: number
          used_at?: string | null
          user_id?: string | null
        }
        Update: {
          booking_date?: string | null
          event_id?: string | null
          id?: string
          payment_method?: string | null
          payment_status?: string | null
          qr_code?: string | null
          status?: string | null
          ticket_code?: string | null
          ticket_quantity?: number | null
          total_price?: number
          used_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_bookings_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_categories: {
        Row: {
          color: string | null
          created_at: string | null
          display_order: number | null
          icon: string | null
          id: string
          name: string
          slug: string
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          display_order?: number | null
          icon?: string | null
          id?: string
          name: string
          slug: string
        }
        Update: {
          color?: string | null
          created_at?: string | null
          display_order?: number | null
          icon?: string | null
          id?: string
          name?: string
          slug?: string
        }
        Relationships: []
      }
      event_favorites: {
        Row: {
          created_at: string | null
          event_id: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          event_id?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          event_id?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_favorites_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_interests: {
        Row: {
          event_id: string
          id: string
          interested_at: string | null
          user_id: string | null
        }
        Insert: {
          event_id: string
          id?: string
          interested_at?: string | null
          user_id?: string | null
        }
        Update: {
          event_id?: string
          id?: string
          interested_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      event_notifications: {
        Row: {
          event_id: string | null
          id: string
          is_read: boolean | null
          message: string | null
          read_at: string | null
          sent_at: string | null
          title: string
          type: string
          user_id: string | null
        }
        Insert: {
          event_id?: string | null
          id?: string
          is_read?: boolean | null
          message?: string | null
          read_at?: string | null
          sent_at?: string | null
          title: string
          type: string
          user_id?: string | null
        }
        Update: {
          event_id?: string | null
          id?: string
          is_read?: boolean | null
          message?: string | null
          read_at?: string | null
          sent_at?: string | null
          title?: string
          type?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_notifications_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_reviews: {
        Row: {
          comment: string | null
          created_at: string | null
          event_id: string | null
          id: string
          rating: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          comment?: string | null
          created_at?: string | null
          event_id?: string | null
          id?: string
          rating?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          comment?: string | null
          created_at?: string | null
          event_id?: string | null
          id?: string
          rating?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_reviews_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_seats: {
        Row: {
          booking_id: string | null
          category: string | null
          created_at: string | null
          event_id: string | null
          id: string
          number: number
          price: number | null
          reserved_by: string | null
          reserved_until: string | null
          row: string
          status: string | null
        }
        Insert: {
          booking_id?: string | null
          category?: string | null
          created_at?: string | null
          event_id?: string | null
          id?: string
          number: number
          price?: number | null
          reserved_by?: string | null
          reserved_until?: string | null
          row: string
          status?: string | null
        }
        Update: {
          booking_id?: string | null
          category?: string | null
          created_at?: string | null
          event_id?: string | null
          id?: string
          number?: number
          price?: number | null
          reserved_by?: string | null
          reserved_until?: string | null
          row?: string
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_seats_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_waiting_queue: {
        Row: {
          event_id: string | null
          id: string
          joined_at: string | null
          position: number
          processed_at: string | null
          quantity: number | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          event_id?: string | null
          id?: string
          joined_at?: string | null
          position: number
          processed_at?: string | null
          quantity?: number | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          event_id?: string | null
          id?: string
          joined_at?: string | null
          position?: number
          processed_at?: string | null
          quantity?: number | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_waiting_queue_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          address: string | null
          banner_url: string | null
          capacity: number | null
          category: string
          city: string | null
          contact_email: string | null
          contact_phone: string | null
          created_at: string | null
          description: string
          end_date: string | null
          id: string
          image_url: string | null
          is_featured: boolean | null
          is_free: boolean | null
          likes_count: number | null
          location: string
          organizer_id: string | null
          organizer_name: string | null
          price: number | null
          price_currency: string | null
          remaining_tickets: number | null
          shares_count: number | null
          start_date: string
          status: string | null
          sub_category: string | null
          title: string
          updated_at: string | null
          views_count: number | null
        }
        Insert: {
          address?: string | null
          banner_url?: string | null
          capacity?: number | null
          category: string
          city?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          description: string
          end_date?: string | null
          id?: string
          image_url?: string | null
          is_featured?: boolean | null
          is_free?: boolean | null
          likes_count?: number | null
          location: string
          organizer_id?: string | null
          organizer_name?: string | null
          price?: number | null
          price_currency?: string | null
          remaining_tickets?: number | null
          shares_count?: number | null
          start_date: string
          status?: string | null
          sub_category?: string | null
          title: string
          updated_at?: string | null
          views_count?: number | null
        }
        Update: {
          address?: string | null
          banner_url?: string | null
          capacity?: number | null
          category?: string
          city?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          description?: string
          end_date?: string | null
          id?: string
          image_url?: string | null
          is_featured?: boolean | null
          is_free?: boolean | null
          likes_count?: number | null
          location?: string
          organizer_id?: string | null
          organizer_name?: string | null
          price?: number | null
          price_currency?: string | null
          remaining_tickets?: number | null
          shares_count?: number | null
          start_date?: string
          status?: string | null
          sub_category?: string | null
          title?: string
          updated_at?: string | null
          views_count?: number | null
        }
        Relationships: []
      }
      exams: {
        Row: {
          created_at: string
          date: string
          doctor_id: string | null
          doctor_name: string | null
          id: string
          is_abnormal: boolean | null
          notes: string | null
          patient_id: string
          patient_name: string
          priority: Database["public"]["Enums"]["exam_priority_enum"] | null
          reference_range: string | null
          result: string | null
          status: Database["public"]["Enums"]["exam_status_enum"] | null
          type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date?: string
          doctor_id?: string | null
          doctor_name?: string | null
          id?: string
          is_abnormal?: boolean | null
          notes?: string | null
          patient_id: string
          patient_name: string
          priority?: Database["public"]["Enums"]["exam_priority_enum"] | null
          reference_range?: string | null
          result?: string | null
          status?: Database["public"]["Enums"]["exam_status_enum"] | null
          type: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date?: string
          doctor_id?: string | null
          doctor_name?: string | null
          id?: string
          is_abnormal?: boolean | null
          notes?: string | null
          patient_id?: string
          patient_name?: string
          priority?: Database["public"]["Enums"]["exam_priority_enum"] | null
          reference_range?: string | null
          result?: string | null
          status?: Database["public"]["Enums"]["exam_status_enum"] | null
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "exams_doctor_id_fkey"
            columns: ["doctor_id"]
            isOneToOne: false
            referencedRelation: "doctors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "exams_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      exchange_rates: {
        Row: {
          change_24h: number | null
          currency_code: string
          currency_name: string
          id: string
          rate: number
          updated_at: string
        }
        Insert: {
          change_24h?: number | null
          currency_code: string
          currency_name: string
          id?: string
          rate: number
          updated_at?: string
        }
        Update: {
          change_24h?: number | null
          currency_code?: string
          currency_name?: string
          id?: string
          rate?: number
          updated_at?: string
        }
        Relationships: []
      }
      experience: {
        Row: {
          company_name: string | null
          created_at: string | null
          description: string | null
          end_date: string | null
          id: string
          is_public: boolean | null
          is_verified: boolean | null
          position: string | null
          start_date: string | null
          user_id: string | null
        }
        Insert: {
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          position?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Update: {
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          is_public?: boolean | null
          is_verified?: boolean | null
          position?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "experience_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      experiences: {
        Row: {
          company: string | null
          company_name: string | null
          created_at: string | null
          description: string | null
          employer: string | null
          entreprise: string | null
          id: string
          missions: string | null
          position: string | null
          secteur: string | null
          titre_poste: string | null
          user_id: string | null
          ville: string | null
        }
        Insert: {
          company?: string | null
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          employer?: string | null
          entreprise?: string | null
          id?: string
          missions?: string | null
          position?: string | null
          secteur?: string | null
          titre_poste?: string | null
          user_id?: string | null
          ville?: string | null
        }
        Update: {
          company?: string | null
          company_name?: string | null
          created_at?: string | null
          description?: string | null
          employer?: string | null
          entreprise?: string | null
          id?: string
          missions?: string | null
          position?: string | null
          secteur?: string | null
          titre_poste?: string | null
          user_id?: string | null
          ville?: string | null
        }
        Relationships: []
      }
      favoris: {
        Row: {
          created_at: string | null
          id: string
          item_id: string
          type: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          item_id: string
          type: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          item_id?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      formations: {
        Row: {
          duration: string | null
          end_date: string | null
          id: string
          organizer: string | null
          skills: string | null
          start_date: string | null
          title: string | null
          type: string | null
          user_id: string | null
        }
        Insert: {
          duration?: string | null
          end_date?: string | null
          id?: string
          organizer?: string | null
          skills?: string | null
          start_date?: string | null
          title?: string | null
          type?: string | null
          user_id?: string | null
        }
        Update: {
          duration?: string | null
          end_date?: string | null
          id?: string
          organizer?: string | null
          skills?: string | null
          start_date?: string | null
          title?: string | null
          type?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "formations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fraud_logs: {
        Row: {
          created_at: string | null
          id: string
          metadata: Json | null
          reason: string | null
          risk_level: string | null
          risk_score: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          metadata?: Json | null
          reason?: string | null
          risk_level?: string | null
          risk_score?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          metadata?: Json | null
          reason?: string | null
          risk_level?: string | null
          risk_score?: number | null
          user_id?: string | null
        }
        Relationships: []
      }
      hashtags: {
        Row: {
          created_at: string | null
          id: string
          name: string
          posts_count: number | null
          trending_at: string | null
          trending_score: number | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          name: string
          posts_count?: number | null
          trending_at?: string | null
          trending_score?: number | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string
          posts_count?: number | null
          trending_at?: string | null
          trending_score?: number | null
        }
        Relationships: []
      }
      health_alerts: {
        Row: {
          action_url: string | null
          created_at: string | null
          date: string
          description: string
          doctor_id: string | null
          id: string
          is_read: boolean | null
          patient_id: string
          severity: string
          source: string | null
          title: string
          updated_at: string | null
        }
        Insert: {
          action_url?: string | null
          created_at?: string | null
          date: string
          description: string
          doctor_id?: string | null
          id?: string
          is_read?: boolean | null
          patient_id: string
          severity?: string
          source?: string | null
          title: string
          updated_at?: string | null
        }
        Update: {
          action_url?: string | null
          created_at?: string | null
          date?: string
          description?: string
          doctor_id?: string | null
          id?: string
          is_read?: boolean | null
          patient_id?: string
          severity?: string
          source?: string | null
          title?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_appointments: {
        Row: {
          created_at: string | null
          doctor_id: string
          doctor_name: string
          doctor_specialty: string | null
          id: string
          is_emergency: boolean | null
          notes: string | null
          patient_id: string
          patient_name: string | null
          scheduled_at: string
          status: string
          teleconsultation_link: string | null
          type: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          doctor_id: string
          doctor_name: string
          doctor_specialty?: string | null
          id?: string
          is_emergency?: boolean | null
          notes?: string | null
          patient_id: string
          patient_name?: string | null
          scheduled_at: string
          status?: string
          teleconsultation_link?: string | null
          type?: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          doctor_id?: string
          doctor_name?: string
          doctor_specialty?: string | null
          id?: string
          is_emergency?: boolean | null
          notes?: string | null
          patient_id?: string
          patient_name?: string | null
          scheduled_at?: string
          status?: string
          teleconsultation_link?: string | null
          type?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_articles: {
        Row: {
          author: string | null
          content: string
          created_at: string | null
          id: string
          image_url: string | null
          is_published: boolean | null
          read_time: number | null
          tags: string[] | null
          title: string
          updated_at: string | null
          views_count: number | null
        }
        Insert: {
          author?: string | null
          content: string
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean | null
          read_time?: number | null
          tags?: string[] | null
          title: string
          updated_at?: string | null
          views_count?: number | null
        }
        Update: {
          author?: string | null
          content?: string
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean | null
          read_time?: number | null
          tags?: string[] | null
          title?: string
          updated_at?: string | null
          views_count?: number | null
        }
        Relationships: []
      }
      health_consents: {
        Row: {
          created_at: string | null
          date: string
          expiry_date: string | null
          granted: boolean | null
          id: string
          patient_id: string
          type: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          date: string
          expiry_date?: string | null
          granted?: boolean | null
          id?: string
          patient_id: string
          type: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          date?: string
          expiry_date?: string | null
          granted?: boolean | null
          id?: string
          patient_id?: string
          type?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_consultations: {
        Row: {
          appointment_date: string
          created_at: string | null
          doctor_id: string | null
          id: string
          is_virtual: boolean | null
          location: string | null
          notes: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          appointment_date: string
          created_at?: string | null
          doctor_id?: string | null
          id?: string
          is_virtual?: boolean | null
          location?: string | null
          notes?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          appointment_date?: string
          created_at?: string | null
          doctor_id?: string | null
          id?: string
          is_virtual?: boolean | null
          location?: string | null
          notes?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_consultations_doctor_id_fkey"
            columns: ["doctor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "health_consultations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_doctor_slots: {
        Row: {
          created_at: string | null
          doctor_id: string
          end_at: string
          id: string
          is_booked: boolean | null
          start_at: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          doctor_id: string
          end_at: string
          id?: string
          is_booked?: boolean | null
          start_at: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          doctor_id?: string
          end_at?: string
          id?: string
          is_booked?: boolean | null
          start_at?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_emergency_calls: {
        Row: {
          call_date: string | null
          duration: number | null
          id: string
          notes: string | null
          user_id: string | null
        }
        Insert: {
          call_date?: string | null
          duration?: number | null
          id?: string
          notes?: string | null
          user_id?: string | null
        }
        Update: {
          call_date?: string | null
          duration?: number | null
          id?: string
          notes?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_emergency_calls_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_examens: {
        Row: {
          created_at: string | null
          doctor_comment: string | null
          exam_date: string
          id: string
          laboratory: string | null
          result_url: string | null
          results: Json | null
          title: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          doctor_comment?: string | null
          exam_date: string
          id?: string
          laboratory?: string | null
          result_url?: string | null
          results?: Json | null
          title: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          doctor_comment?: string | null
          exam_date?: string
          id?: string
          laboratory?: string | null
          result_url?: string | null
          results?: Json | null
          title?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_examens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_exams: {
        Row: {
          comments: string | null
          created_at: string | null
          exam_name: string
          id: string
          image_url: string | null
          patient_id: string
          pdf_url: string | null
          performed_at: string
          result: string | null
          status: string
          updated_at: string | null
        }
        Insert: {
          comments?: string | null
          created_at?: string | null
          exam_name: string
          id?: string
          image_url?: string | null
          patient_id: string
          pdf_url?: string | null
          performed_at: string
          result?: string | null
          status?: string
          updated_at?: string | null
        }
        Update: {
          comments?: string | null
          created_at?: string | null
          exam_name?: string
          id?: string
          image_url?: string | null
          patient_id?: string
          pdf_url?: string | null
          performed_at?: string
          result?: string | null
          status?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_facilities: {
        Row: {
          address: string | null
          created_at: string | null
          id: string
          is_24h: boolean | null
          is_active: boolean | null
          is_emergency: boolean | null
          latitude: number | null
          longitude: number | null
          name: string
          phone: string | null
          rating: number | null
          type: string
        }
        Insert: {
          address?: string | null
          created_at?: string | null
          id?: string
          is_24h?: boolean | null
          is_active?: boolean | null
          is_emergency?: boolean | null
          latitude?: number | null
          longitude?: number | null
          name: string
          phone?: string | null
          rating?: number | null
          type: string
        }
        Update: {
          address?: string | null
          created_at?: string | null
          id?: string
          is_24h?: boolean | null
          is_active?: boolean | null
          is_emergency?: boolean | null
          latitude?: number | null
          longitude?: number | null
          name?: string
          phone?: string | null
          rating?: number | null
          type?: string
        }
        Relationships: []
      }
      health_hospitals: {
        Row: {
          address: string
          created_at: string | null
          email: string | null
          emergency_service: boolean | null
          id: string
          is_open: boolean | null
          lat: number | null
          lng: number | null
          name: string
          phone: string | null
          updated_at: string | null
        }
        Insert: {
          address: string
          created_at?: string | null
          email?: string | null
          emergency_service?: boolean | null
          id?: string
          is_open?: boolean | null
          lat?: number | null
          lng?: number | null
          name: string
          phone?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string
          created_at?: string | null
          email?: string | null
          emergency_service?: boolean | null
          id?: string
          is_open?: boolean | null
          lat?: number | null
          lng?: number | null
          name?: string
          phone?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      health_insurance_offers: {
        Row: {
          annual_price: number
          benefits: string[] | null
          coverage: string
          created_at: string | null
          description: string
          id: string
          is_popular: boolean | null
          monthly_price: number
          title: string
          updated_at: string | null
        }
        Insert: {
          annual_price: number
          benefits?: string[] | null
          coverage: string
          created_at?: string | null
          description: string
          id?: string
          is_popular?: boolean | null
          monthly_price: number
          title: string
          updated_at?: string | null
        }
        Update: {
          annual_price?: number
          benefits?: string[] | null
          coverage?: string
          created_at?: string | null
          description?: string
          id?: string
          is_popular?: boolean | null
          monthly_price?: number
          title?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_medicaments: {
        Row: {
          created_at: string | null
          id: string
          name: string
          pharmacies: string | null
          price: string | null
          type: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          name: string
          pharmacies?: string | null
          price?: string | null
          type?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string
          pharmacies?: string | null
          price?: string | null
          type?: string | null
        }
        Relationships: []
      }
      health_medication_reminders: {
        Row: {
          created_at: string | null
          days_of_week: number[] | null
          id: string
          is_enabled: boolean | null
          medication_id: string
          time: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          days_of_week?: number[] | null
          id?: string
          is_enabled?: boolean | null
          medication_id: string
          time: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          days_of_week?: number[] | null
          id?: string
          is_enabled?: boolean | null
          medication_id?: string
          time?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_medication_reminders_medication_id_fkey"
            columns: ["medication_id"]
            isOneToOne: false
            referencedRelation: "health_medications"
            referencedColumns: ["id"]
          },
        ]
      }
      health_medications: {
        Row: {
          created_at: string | null
          dosage: string
          duration: string | null
          end_date: string | null
          frequency: string
          id: string
          instructions: string | null
          is_active: boolean | null
          name: string
          patient_id: string
          prescribed_by: string | null
          prescription_id: string | null
          start_date: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          dosage: string
          duration?: string | null
          end_date?: string | null
          frequency: string
          id?: string
          instructions?: string | null
          is_active?: boolean | null
          name: string
          patient_id: string
          prescribed_by?: string | null
          prescription_id?: string | null
          start_date: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          dosage?: string
          duration?: string | null
          end_date?: string | null
          frequency?: string
          id?: string
          instructions?: string | null
          is_active?: boolean | null
          name?: string
          patient_id?: string
          prescribed_by?: string | null
          prescription_id?: string | null
          start_date?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_messages: {
        Row: {
          content: string
          created_at: string | null
          id: string
          is_read: boolean | null
          recipient_id: string
          sender_id: string
          updated_at: string | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          recipient_id: string
          sender_id: string
          updated_at?: string | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          recipient_id?: string
          sender_id?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_order_items: {
        Row: {
          created_at: string | null
          dosage: string | null
          id: string
          order_id: string
          product_name: string
          quantity: number
          unit_price: number
        }
        Insert: {
          created_at?: string | null
          dosage?: string | null
          id?: string
          order_id: string
          product_name: string
          quantity: number
          unit_price: number
        }
        Update: {
          created_at?: string | null
          dosage?: string | null
          id?: string
          order_id?: string
          product_name?: string
          quantity?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "health_order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "health_pharmacy_orders"
            referencedColumns: ["id"]
          },
        ]
      }
      health_ordonnances: {
        Row: {
          created_at: string | null
          doctor_id: string | null
          expires_at: string | null
          id: string
          instructions: string | null
          medicaments: Json | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          doctor_id?: string | null
          expires_at?: string | null
          id?: string
          instructions?: string | null
          medicaments?: Json | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          doctor_id?: string | null
          expires_at?: string | null
          id?: string
          instructions?: string | null
          medicaments?: Json | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_ordonnances_doctor_id_fkey"
            columns: ["doctor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "health_ordonnances_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_pharmacies: {
        Row: {
          address: string
          created_at: string | null
          email: string | null
          id: string
          is_open: boolean | null
          lat: number | null
          lng: number | null
          name: string
          phone: string | null
          updated_at: string | null
        }
        Insert: {
          address: string
          created_at?: string | null
          email?: string | null
          id?: string
          is_open?: boolean | null
          lat?: number | null
          lng?: number | null
          name: string
          phone?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string
          created_at?: string | null
          email?: string | null
          id?: string
          is_open?: boolean | null
          lat?: number | null
          lng?: number | null
          name?: string
          phone?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      health_pharmacy_inventory_items: {
        Row: {
          batch_number: string | null
          created_at: string | null
          dosage: string | null
          expiry_date: string | null
          id: string
          is_critical: boolean | null
          pharmacy_id: string
          product_name: string
          quantity: number
          threshold: number
          unit_price: number
          updated_at: string | null
        }
        Insert: {
          batch_number?: string | null
          created_at?: string | null
          dosage?: string | null
          expiry_date?: string | null
          id?: string
          is_critical?: boolean | null
          pharmacy_id: string
          product_name: string
          quantity: number
          threshold: number
          unit_price: number
          updated_at?: string | null
        }
        Update: {
          batch_number?: string | null
          created_at?: string | null
          dosage?: string | null
          expiry_date?: string | null
          id?: string
          is_critical?: boolean | null
          pharmacy_id?: string
          product_name?: string
          quantity?: number
          threshold?: number
          unit_price?: number
          updated_at?: string | null
        }
        Relationships: []
      }
      health_pharmacy_orders: {
        Row: {
          created_at: string | null
          delivery_date: string | null
          id: string
          notes: string | null
          order_date: string
          patient_id: string | null
          patient_name: string | null
          pharmacy_id: string
          status: string | null
          total_amount: number
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          delivery_date?: string | null
          id?: string
          notes?: string | null
          order_date: string
          patient_id?: string | null
          patient_name?: string | null
          pharmacy_id: string
          status?: string | null
          total_amount: number
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          delivery_date?: string | null
          id?: string
          notes?: string | null
          order_date?: string
          patient_id?: string | null
          patient_name?: string | null
          pharmacy_id?: string
          status?: string | null
          total_amount?: number
          updated_at?: string | null
        }
        Relationships: []
      }
      health_pregnancies: {
        Row: {
          created_at: string | null
          current_week: number | null
          expected_date: string | null
          id: string
          notes: string | null
          start_date: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          current_week?: number | null
          expected_date?: string | null
          id?: string
          notes?: string | null
          start_date: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          current_week?: number | null
          expected_date?: string | null
          id?: string
          notes?: string | null
          start_date?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_pregnancies_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_pregnancy_appointments: {
        Row: {
          appointment_date: string
          created_at: string | null
          doctor: string | null
          id: string
          notes: string | null
          pregnancy_id: string | null
          title: string
        }
        Insert: {
          appointment_date: string
          created_at?: string | null
          doctor?: string | null
          id?: string
          notes?: string | null
          pregnancy_id?: string | null
          title: string
        }
        Update: {
          appointment_date?: string
          created_at?: string | null
          doctor?: string | null
          id?: string
          notes?: string | null
          pregnancy_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "health_pregnancy_appointments_pregnancy_id_fkey"
            columns: ["pregnancy_id"]
            isOneToOne: false
            referencedRelation: "health_pregnancies"
            referencedColumns: ["id"]
          },
        ]
      }
      health_pregnancy_symptoms: {
        Row: {
          created_at: string | null
          date: string
          id: string
          name: string
          notes: string | null
          pregnancy_id: string | null
          severity: number | null
        }
        Insert: {
          created_at?: string | null
          date: string
          id?: string
          name: string
          notes?: string | null
          pregnancy_id?: string | null
          severity?: number | null
        }
        Update: {
          created_at?: string | null
          date?: string
          id?: string
          name?: string
          notes?: string | null
          pregnancy_id?: string | null
          severity?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "health_pregnancy_symptoms_pregnancy_id_fkey"
            columns: ["pregnancy_id"]
            isOneToOne: false
            referencedRelation: "health_pregnancies"
            referencedColumns: ["id"]
          },
        ]
      }
      health_prescriptions: {
        Row: {
          created_at: string | null
          doctor_id: string
          doctor_name: string
          id: string
          issued_at: string
          notes: string | null
          patient_id: string
          patient_name: string | null
          status: string
          updated_at: string | null
          valid_until: string | null
        }
        Insert: {
          created_at?: string | null
          doctor_id: string
          doctor_name: string
          id?: string
          issued_at: string
          notes?: string | null
          patient_id: string
          patient_name?: string | null
          status?: string
          updated_at?: string | null
          valid_until?: string | null
        }
        Update: {
          created_at?: string | null
          doctor_id?: string
          doctor_name?: string
          id?: string
          issued_at?: string
          notes?: string | null
          patient_id?: string
          patient_name?: string | null
          status?: string
          updated_at?: string | null
          valid_until?: string | null
        }
        Relationships: []
      }
      health_services: {
        Row: {
          created_at: string | null
          icon: string | null
          id: string
          is_active: boolean | null
          name: string
          order_index: number | null
          route: string | null
        }
        Insert: {
          created_at?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean | null
          name: string
          order_index?: number | null
          route?: string | null
        }
        Update: {
          created_at?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean | null
          name?: string
          order_index?: number | null
          route?: string | null
        }
        Relationships: []
      }
      health_shares: {
        Row: {
          access_level: string
          created_at: string | null
          expires_at: string
          id: string
          patient_id: string
          recipient_email: string
          recipient_name: string
          updated_at: string | null
        }
        Insert: {
          access_level?: string
          created_at?: string | null
          expires_at: string
          id?: string
          patient_id: string
          recipient_email: string
          recipient_name: string
          updated_at?: string | null
        }
        Update: {
          access_level?: string
          created_at?: string | null
          expires_at?: string
          id?: string
          patient_id?: string
          recipient_email?: string
          recipient_name?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_stats: {
        Row: {
          consultations_count: number | null
          created_at: string | null
          examens_count: number | null
          has_insurance: boolean | null
          id: string
          insurance_expiry: string | null
          insurance_plan: string | null
          ordonnances_count: number | null
          updated_at: string | null
          urgences_count: number | null
          user_id: string | null
        }
        Insert: {
          consultations_count?: number | null
          created_at?: string | null
          examens_count?: number | null
          has_insurance?: boolean | null
          id?: string
          insurance_expiry?: string | null
          insurance_plan?: string | null
          ordonnances_count?: number | null
          updated_at?: string | null
          urgences_count?: number | null
          user_id?: string | null
        }
        Update: {
          consultations_count?: number | null
          created_at?: string | null
          examens_count?: number | null
          has_insurance?: boolean | null
          id?: string
          insurance_expiry?: string | null
          insurance_plan?: string | null
          ordonnances_count?: number | null
          updated_at?: string | null
          urgences_count?: number | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_stats_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_symptoms: {
        Row: {
          created_at: string | null
          date: string
          duration: number | null
          id: string
          intensity: number | null
          location: string | null
          name: string
          notes: string | null
          patient_id: string
          relievers: string[] | null
          triggers: string[] | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          date: string
          duration?: number | null
          id?: string
          intensity?: number | null
          location?: string | null
          name: string
          notes?: string | null
          patient_id: string
          relievers?: string[] | null
          triggers?: string[] | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          date?: string
          duration?: number | null
          id?: string
          intensity?: number | null
          location?: string | null
          name?: string
          notes?: string | null
          patient_id?: string
          relievers?: string[] | null
          triggers?: string[] | null
          updated_at?: string | null
        }
        Relationships: []
      }
      health_teleexpertise_requests: {
        Row: {
          created_at: string | null
          description: string | null
          doctor_id: string | null
          doctor_name: string | null
          id: string
          patient_id: string
          response: string | null
          status: string | null
          subject: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          doctor_id?: string | null
          doctor_name?: string | null
          id?: string
          patient_id: string
          response?: string | null
          status?: string | null
          subject: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          doctor_id?: string | null
          doctor_name?: string | null
          id?: string
          patient_id?: string
          response?: string | null
          status?: string | null
          subject?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_vaccines: {
        Row: {
          administered_by: string | null
          batch_number: string | null
          booster_date: string | null
          created_at: string | null
          date_administered: string
          id: string
          name: string
          patient_id: string
          updated_at: string | null
        }
        Insert: {
          administered_by?: string | null
          batch_number?: string | null
          booster_date?: string | null
          created_at?: string | null
          date_administered: string
          id?: string
          name: string
          patient_id: string
          updated_at?: string | null
        }
        Update: {
          administered_by?: string | null
          batch_number?: string | null
          booster_date?: string | null
          created_at?: string | null
          date_administered?: string
          id?: string
          name?: string
          patient_id?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      health_vaccins: {
        Row: {
          administered_by: string | null
          batch_number: string | null
          created_at: string | null
          date_administered: string
          id: string
          location: string | null
          name: string
          next_due_date: string | null
          user_id: string | null
        }
        Insert: {
          administered_by?: string | null
          batch_number?: string | null
          created_at?: string | null
          date_administered: string
          id?: string
          location?: string | null
          name: string
          next_due_date?: string | null
          user_id?: string | null
        }
        Update: {
          administered_by?: string | null
          batch_number?: string | null
          created_at?: string | null
          date_administered?: string
          id?: string
          location?: string | null
          name?: string
          next_due_date?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "health_vaccins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      health_vitals: {
        Row: {
          created_at: string | null
          device_used: string | null
          id: string
          measured_at: string
          notes: string | null
          patient_id: string
          type: string
          unit: string | null
          value: number
        }
        Insert: {
          created_at?: string | null
          device_used?: string | null
          id?: string
          measured_at: string
          notes?: string | null
          patient_id: string
          type: string
          unit?: string | null
          value: number
        }
        Update: {
          created_at?: string | null
          device_used?: string | null
          id?: string
          measured_at?: string
          notes?: string | null
          patient_id?: string
          type?: string
          unit?: string | null
          value?: number
        }
        Relationships: []
      }
      health_wellness_programs: {
        Row: {
          category: string
          completed_steps: number | null
          created_at: string | null
          description: string | null
          end_date: string | null
          id: string
          image_url: string | null
          is_active: boolean | null
          patient_id: string
          start_date: string
          subtitle: string | null
          title: string
          total_steps: number | null
          updated_at: string | null
        }
        Insert: {
          category: string
          completed_steps?: number | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean | null
          patient_id: string
          start_date: string
          subtitle?: string | null
          title: string
          total_steps?: number | null
          updated_at?: string | null
        }
        Update: {
          category?: string
          completed_steps?: number | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean | null
          patient_id?: string
          start_date?: string
          subtitle?: string | null
          title?: string
          total_steps?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      hidden_posts: {
        Row: {
          hidden_at: string | null
          id: string
          post_id: string | null
          user_id: string | null
        }
        Insert: {
          hidden_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Update: {
          hidden_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "hidden_posts_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "network_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      home_banners: {
        Row: {
          background_color: string | null
          button_link: string | null
          button_text: string | null
          created_at: string | null
          display_order: number | null
          id: string
          image_url: string | null
          is_active: boolean | null
          subtitle: string
          text_color: string | null
          title: string
        }
        Insert: {
          background_color?: string | null
          button_link?: string | null
          button_text?: string | null
          created_at?: string | null
          display_order?: number | null
          id?: string
          image_url?: string | null
          is_active?: boolean | null
          subtitle: string
          text_color?: string | null
          title: string
        }
        Update: {
          background_color?: string | null
          button_link?: string | null
          button_text?: string | null
          created_at?: string | null
          display_order?: number | null
          id?: string
          image_url?: string | null
          is_active?: boolean | null
          subtitle?: string
          text_color?: string | null
          title?: string
        }
        Relationships: []
      }
      hotel_rooms: {
        Row: {
          amenities: string[] | null
          capacite: number
          created_at: string | null
          description: string | null
          devise: string | null
          est_disponible: boolean | null
          hotel_id: string
          id: string
          images_url: string[] | null
          prix_nuit: number
          quantite: number
          type: string
        }
        Insert: {
          amenities?: string[] | null
          capacite?: number
          created_at?: string | null
          description?: string | null
          devise?: string | null
          est_disponible?: boolean | null
          hotel_id: string
          id?: string
          images_url?: string[] | null
          prix_nuit: number
          quantite?: number
          type: string
        }
        Update: {
          amenities?: string[] | null
          capacite?: number
          created_at?: string | null
          description?: string | null
          devise?: string | null
          est_disponible?: boolean | null
          hotel_id?: string
          id?: string
          images_url?: string[] | null
          prix_nuit?: number
          quantite?: number
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "hotel_rooms_hotel_id_fkey"
            columns: ["hotel_id"]
            isOneToOne: false
            referencedRelation: "hotels"
            referencedColumns: ["id"]
          },
        ]
      }
      hotels: {
        Row: {
          adresse: string | null
          amenities: string[] | null
          avis_count: number | null
          created_at: string | null
          description: string | null
          devise: string | null
          est_actif: boolean | null
          id: string
          images_url: string[] | null
          latitude: number | null
          longitude: number | null
          nom: string
          note: number | null
          pays: string
          prix_min: number
          updated_at: string | null
          ville: string
        }
        Insert: {
          adresse?: string | null
          amenities?: string[] | null
          avis_count?: number | null
          created_at?: string | null
          description?: string | null
          devise?: string | null
          est_actif?: boolean | null
          id?: string
          images_url?: string[] | null
          latitude?: number | null
          longitude?: number | null
          nom: string
          note?: number | null
          pays: string
          prix_min: number
          updated_at?: string | null
          ville: string
        }
        Update: {
          adresse?: string | null
          amenities?: string[] | null
          avis_count?: number | null
          created_at?: string | null
          description?: string | null
          devise?: string | null
          est_actif?: boolean | null
          id?: string
          images_url?: string[] | null
          latitude?: number | null
          longitude?: number | null
          nom?: string
          note?: number | null
          pays?: string
          prix_min?: number
          updated_at?: string | null
          ville?: string
        }
        Relationships: []
      }
      identity_verification: {
        Row: {
          ai_score: number | null
          created_at: string | null
          document_type: string | null
          document_url: string
          id: string
          status: string | null
          user_id: string | null
          verified_at: string | null
        }
        Insert: {
          ai_score?: number | null
          created_at?: string | null
          document_type?: string | null
          document_url: string
          id?: string
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Update: {
          ai_score?: number | null
          created_at?: string | null
          document_type?: string | null
          document_url?: string
          id?: string
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Relationships: []
      }
      insurance_products: {
        Row: {
          color_code: string | null
          coverage_amount: number
          created_at: string
          description: string
          features: string[] | null
          icon: string | null
          id: string
          is_active: boolean
          monthly_premium: number
          name: string
          type: string
        }
        Insert: {
          color_code?: string | null
          coverage_amount: number
          created_at?: string
          description: string
          features?: string[] | null
          icon?: string | null
          id?: string
          is_active?: boolean
          monthly_premium: number
          name: string
          type: string
        }
        Update: {
          color_code?: string | null
          coverage_amount?: number
          created_at?: string
          description?: string
          features?: string[] | null
          icon?: string | null
          id?: string
          is_active?: boolean
          monthly_premium?: number
          name?: string
          type?: string
        }
        Relationships: []
      }
      investment_products: {
        Row: {
          color_code: string | null
          created_at: string
          description: string
          duration_days: number
          icon: string | null
          id: string
          is_active: boolean
          max_amount: number
          min_amount: number
          name: string
          return_rate: number
          risk_level: string
        }
        Insert: {
          color_code?: string | null
          created_at?: string
          description: string
          duration_days: number
          icon?: string | null
          id?: string
          is_active?: boolean
          max_amount: number
          min_amount: number
          name: string
          return_rate: number
          risk_level: string
        }
        Update: {
          color_code?: string | null
          created_at?: string
          description?: string
          duration_days?: number
          icon?: string | null
          id?: string
          is_active?: boolean
          max_amount?: number
          min_amount?: number
          name?: string
          return_rate?: number
          risk_level?: string
        }
        Relationships: []
      }
      jobs: {
        Row: {
          company_id: string | null
          created_at: string | null
          description: string | null
          id: string
          posted_by: string | null
          title: string
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          posted_by?: string | null
          title: string
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          posted_by?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "jobs_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      languages: {
        Row: {
          created_at: string | null
          id: string
          language_name: string | null
          proficiency_level: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          language_name?: string | null
          proficiency_level?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          language_name?: string | null
          proficiency_level?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      lesson_resources: {
        Row: {
          created_at: string | null
          file_size: number | null
          id: string
          lesson_id: string | null
          title: string
          type: string
          url: string
        }
        Insert: {
          created_at?: string | null
          file_size?: number | null
          id?: string
          lesson_id?: string | null
          title: string
          type: string
          url: string
        }
        Update: {
          created_at?: string | null
          file_size?: number | null
          id?: string
          lesson_id?: string | null
          title?: string
          type?: string
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "lesson_resources_lesson_id_fkey"
            columns: ["lesson_id"]
            isOneToOne: false
            referencedRelation: "training_lessons"
            referencedColumns: ["id"]
          },
        ]
      }
      live_messages: {
        Row: {
          created_at: string | null
          id: string
          live_id: string
          message: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          live_id: string
          message: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          live_id?: string
          message?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_messages_live_id_fkey"
            columns: ["live_id"]
            isOneToOne: false
            referencedRelation: "lives"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_messages_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      lives: {
        Row: {
          auction_end_time: string | null
          channel_name: string
          created_at: string | null
          description: string | null
          duration_seconds: number | null
          ended_at: string | null
          has_auction: boolean | null
          id: string
          products: string[] | null
          scheduled_start: string
          shop_id: string
          started_at: string | null
          starting_price: number | null
          status: string | null
          thumbnail_url: string | null
          title: string
          token: string | null
          viewer_count: number | null
        }
        Insert: {
          auction_end_time?: string | null
          channel_name: string
          created_at?: string | null
          description?: string | null
          duration_seconds?: number | null
          ended_at?: string | null
          has_auction?: boolean | null
          id?: string
          products?: string[] | null
          scheduled_start: string
          shop_id: string
          started_at?: string | null
          starting_price?: number | null
          status?: string | null
          thumbnail_url?: string | null
          title: string
          token?: string | null
          viewer_count?: number | null
        }
        Update: {
          auction_end_time?: string | null
          channel_name?: string
          created_at?: string | null
          description?: string | null
          duration_seconds?: number | null
          ended_at?: string | null
          has_auction?: boolean | null
          id?: string
          products?: string[] | null
          scheduled_start?: string
          shop_id?: string
          started_at?: string | null
          starting_price?: number | null
          status?: string | null
          thumbnail_url?: string | null
          title?: string
          token?: string | null
          viewer_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "lives_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          city: string | null
          commune: string | null
          id: string
          province: string | null
          territory: string | null
        }
        Insert: {
          city?: string | null
          commune?: string | null
          id?: string
          province?: string | null
          territory?: string | null
        }
        Update: {
          city?: string | null
          commune?: string | null
          id?: string
          province?: string | null
          territory?: string | null
        }
        Relationships: []
      }
      market_conversations: {
        Row: {
          buyer_avatar: string | null
          buyer_id: string
          buyer_name: string
          created_at: string | null
          id: string
          is_active: boolean | null
          last_message: string | null
          last_message_at: string | null
          product_id: string
          product_image: string | null
          product_title: string
          seller_avatar: string | null
          seller_id: string
          seller_name: string
          unread_count: number | null
        }
        Insert: {
          buyer_avatar?: string | null
          buyer_id: string
          buyer_name: string
          created_at?: string | null
          id?: string
          is_active?: boolean | null
          last_message?: string | null
          last_message_at?: string | null
          product_id: string
          product_image?: string | null
          product_title: string
          seller_avatar?: string | null
          seller_id: string
          seller_name: string
          unread_count?: number | null
        }
        Update: {
          buyer_avatar?: string | null
          buyer_id?: string
          buyer_name?: string
          created_at?: string | null
          id?: string
          is_active?: boolean | null
          last_message?: string | null
          last_message_at?: string | null
          product_id?: string
          product_image?: string | null
          product_title?: string
          seller_avatar?: string | null
          seller_id?: string
          seller_name?: string
          unread_count?: number | null
        }
        Relationships: []
      }
      market_messages: {
        Row: {
          conversation_id: string | null
          created_at: string | null
          id: string
          image_url: string | null
          is_read: boolean | null
          message: string
          sender_avatar: string | null
          sender_id: string
          sender_name: string
        }
        Insert: {
          conversation_id?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_read?: boolean | null
          message: string
          sender_avatar?: string | null
          sender_id: string
          sender_name: string
        }
        Update: {
          conversation_id?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          is_read?: boolean | null
          message?: string
          sender_avatar?: string | null
          sender_id?: string
          sender_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "market_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "market_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      market_orders: {
        Row: {
          created_at: string | null
          id: string
          items: Json
          order_number: string
          shipping_address: string | null
          status: string | null
          total: number
          tracking_number: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id: string
          items: Json
          order_number: string
          shipping_address?: string | null
          status?: string | null
          total: number
          tracking_number?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          items?: Json
          order_number?: string
          shipping_address?: string | null
          status?: string | null
          total?: number
          tracking_number?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      market_products: {
        Row: {
          category: string
          city: string | null
          country: string | null
          created_at: string | null
          description: string | null
          flash_discount: number | null
          id: string
          image_url: string | null
          in_stock: boolean | null
          is_featured: boolean | null
          is_flash_sale: boolean | null
          old_price: number | null
          price: number
          rating: number | null
          reviews_count: number | null
          seller: string
          seller_avatar: string | null
          seller_id: string | null
          stock: number | null
          title: string
          updated_at: string | null
        }
        Insert: {
          category: string
          city?: string | null
          country?: string | null
          created_at?: string | null
          description?: string | null
          flash_discount?: number | null
          id?: string
          image_url?: string | null
          in_stock?: boolean | null
          is_featured?: boolean | null
          is_flash_sale?: boolean | null
          old_price?: number | null
          price: number
          rating?: number | null
          reviews_count?: number | null
          seller: string
          seller_avatar?: string | null
          seller_id?: string | null
          stock?: number | null
          title: string
          updated_at?: string | null
        }
        Update: {
          category?: string
          city?: string | null
          country?: string | null
          created_at?: string | null
          description?: string | null
          flash_discount?: number | null
          id?: string
          image_url?: string | null
          in_stock?: boolean | null
          is_featured?: boolean | null
          is_flash_sale?: boolean | null
          old_price?: number | null
          price?: number
          rating?: number | null
          reviews_count?: number | null
          seller?: string
          seller_avatar?: string | null
          seller_id?: string | null
          stock?: number | null
          title?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      media_contents: {
        Row: {
          cover_url: string | null
          created_at: string | null
          description: string | null
          id: string
          is_new_release: boolean | null
          is_published: boolean | null
          is_recommended: boolean | null
          is_trending: boolean | null
          rank_position: number | null
          subtitle: string | null
          tags: string[] | null
          title: string
          type: string
          updated_at: string | null
          video_url: string
          view_count: number | null
          year: string | null
        }
        Insert: {
          cover_url?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_new_release?: boolean | null
          is_published?: boolean | null
          is_recommended?: boolean | null
          is_trending?: boolean | null
          rank_position?: number | null
          subtitle?: string | null
          tags?: string[] | null
          title: string
          type: string
          updated_at?: string | null
          video_url: string
          view_count?: number | null
          year?: string | null
        }
        Update: {
          cover_url?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_new_release?: boolean | null
          is_published?: boolean | null
          is_recommended?: boolean | null
          is_trending?: boolean | null
          rank_position?: number | null
          subtitle?: string | null
          tags?: string[] | null
          title?: string
          type?: string
          updated_at?: string | null
          video_url?: string
          view_count?: number | null
          year?: string | null
        }
        Relationships: []
      }
      mediations: {
        Row: {
          created_at: string | null
          dispute_id: string
          id: string
          mediator_id: string | null
          requested_at: string | null
          requested_by: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          dispute_id: string
          id?: string
          mediator_id?: string | null
          requested_at?: string | null
          requested_by?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          dispute_id?: string
          id?: string
          mediator_id?: string | null
          requested_at?: string | null
          requested_by?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "mediations_dispute_id_fkey"
            columns: ["dispute_id"]
            isOneToOne: false
            referencedRelation: "disputes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mediations_mediator_id_fkey"
            columns: ["mediator_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mediations_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      medications: {
        Row: {
          batch_number: string | null
          created_at: string
          dosage: string
          expiry_date: string | null
          form: string | null
          id: string
          name: string
          price: number | null
          quantity: number
          status: Database["public"]["Enums"]["status_enum"] | null
          threshold: number | null
          updated_at: string
        }
        Insert: {
          batch_number?: string | null
          created_at?: string
          dosage: string
          expiry_date?: string | null
          form?: string | null
          id?: string
          name: string
          price?: number | null
          quantity?: number
          status?: Database["public"]["Enums"]["status_enum"] | null
          threshold?: number | null
          updated_at?: string
        }
        Update: {
          batch_number?: string | null
          created_at?: string
          dosage?: string
          expiry_date?: string | null
          form?: string | null
          id?: string
          name?: string
          price?: number | null
          quantity?: number
          status?: Database["public"]["Enums"]["status_enum"] | null
          threshold?: number | null
          updated_at?: string
        }
        Relationships: []
      }
      message_reactions: {
        Row: {
          created_at: string | null
          id: string
          message_id: string
          reaction: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          message_id: string
          reaction: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          message_id?: string
          reaction?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_reactions_message"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_reactions_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      message_reports: {
        Row: {
          created_at: string | null
          id: string
          message_id: string
          reason: string
          reporter_user_id: string
          reviewed_at: string | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          message_id: string
          reason: string
          reporter_user_id: string
          reviewed_at?: string | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          message_id?: string
          reason?: string
          reporter_user_id?: string
          reviewed_at?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_report_message"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_report_reporter"
            columns: ["reporter_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          content: string | null
          conversation_id: string
          created_at: string | null
          duration_seconds: number | null
          edited_at: string | null
          file_size: number | null
          id: string
          is_deleted: boolean | null
          media_url: string | null
          metadata: Json | null
          reactions: string[] | null
          sender_id: string
          sent_at: string | null
          thumbnail_url: string | null
          type: string
        }
        Insert: {
          content?: string | null
          conversation_id: string
          created_at?: string | null
          duration_seconds?: number | null
          edited_at?: string | null
          file_size?: number | null
          id?: string
          is_deleted?: boolean | null
          media_url?: string | null
          metadata?: Json | null
          reactions?: string[] | null
          sender_id: string
          sent_at?: string | null
          thumbnail_url?: string | null
          type: string
        }
        Update: {
          content?: string | null
          conversation_id?: string
          created_at?: string | null
          duration_seconds?: number | null
          edited_at?: string | null
          file_size?: number | null
          id?: string
          is_deleted?: boolean | null
          media_url?: string | null
          metadata?: Json | null
          reactions?: string[] | null
          sender_id?: string
          sent_at?: string | null
          thumbnail_url?: string | null
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_messages_conversation"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_messages_sender"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      national_identity: {
        Row: {
          created_at: string | null
          document_type: string | null
          expiry_date: string | null
          id: string
          id_number: string
          issuance_date: string | null
          issuance_place: string | null
          photo_recto_url: string | null
          photo_selfie_url: string | null
          photo_verso_url: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number: string
          issuance_date?: string | null
          issuance_place?: string | null
          photo_recto_url?: string | null
          photo_selfie_url?: string | null
          photo_verso_url?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number?: string
          issuance_date?: string | null
          issuance_place?: string | null
          photo_recto_url?: string | null
          photo_selfie_url?: string | null
          photo_verso_url?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      network_comments: {
        Row: {
          content: string
          created_at: string | null
          id: string
          likes_count: number | null
          post_id: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          likes_count?: number | null
          post_id?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          likes_count?: number | null
          post_id?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "network_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_comments_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_communities: {
        Row: {
          banner_url: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          id: string
          is_private: boolean | null
          members_count: number | null
          name: string
          posts_count: number | null
          rules: string[] | null
        }
        Insert: {
          banner_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string
          is_private?: boolean | null
          members_count?: number | null
          name: string
          posts_count?: number | null
          rules?: string[] | null
        }
        Update: {
          banner_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string
          is_private?: boolean | null
          members_count?: number | null
          name?: string
          posts_count?: number | null
          rules?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "network_communities_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_connections: {
        Row: {
          created_at: string | null
          id: string
          requester_id: string | null
          status: string | null
          target_id: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          requester_id?: string | null
          status?: string | null
          target_id?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          requester_id?: string | null
          status?: string | null
          target_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_connections_requester_id_fkey"
            columns: ["requester_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_connections_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_conversations: {
        Row: {
          created_at: string | null
          id: string
          last_message: string | null
          last_message_at: string | null
          last_sender_id: string | null
          user1_id: string | null
          user2_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          last_message?: string | null
          last_message_at?: string | null
          last_sender_id?: string | null
          user1_id?: string | null
          user2_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          last_message?: string | null
          last_message_at?: string | null
          last_sender_id?: string | null
          user1_id?: string | null
          user2_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_conversations_last_sender_id_fkey"
            columns: ["last_sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_conversations_user1_id_fkey"
            columns: ["user1_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_conversations_user2_id_fkey"
            columns: ["user2_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_likes: {
        Row: {
          created_at: string | null
          id: string
          post_id: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "network_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_messages: {
        Row: {
          content: string
          conversation_id: string | null
          created_at: string | null
          id: string
          is_deleted_for_everyone: boolean | null
          is_deleted_for_me: boolean | null
          is_read: boolean | null
          receiver_id: string | null
          sender_id: string | null
        }
        Insert: {
          content: string
          conversation_id?: string | null
          created_at?: string | null
          id?: string
          is_deleted_for_everyone?: boolean | null
          is_deleted_for_me?: boolean | null
          is_read?: boolean | null
          receiver_id?: string | null
          sender_id?: string | null
        }
        Update: {
          content?: string
          conversation_id?: string | null
          created_at?: string | null
          id?: string
          is_deleted_for_everyone?: boolean | null
          is_deleted_for_me?: boolean | null
          is_read?: boolean | null
          receiver_id?: string | null
          sender_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "network_conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_messages_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_notifications: {
        Row: {
          actor_avatar: string | null
          actor_id: string | null
          actor_name: string | null
          body: string
          created_at: string | null
          data: Json | null
          id: string
          post_id: string | null
          read: boolean | null
          title: string
          type: string
          user_id: string | null
        }
        Insert: {
          actor_avatar?: string | null
          actor_id?: string | null
          actor_name?: string | null
          body: string
          created_at?: string | null
          data?: Json | null
          id?: string
          post_id?: string | null
          read?: boolean | null
          title: string
          type: string
          user_id?: string | null
        }
        Update: {
          actor_avatar?: string | null
          actor_id?: string | null
          actor_name?: string | null
          body?: string
          created_at?: string | null
          data?: Json | null
          id?: string
          post_id?: string | null
          read?: boolean | null
          title?: string
          type?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_notifications_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_notifications_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "network_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "network_notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_posts: {
        Row: {
          comments_count: number | null
          community_id: string | null
          content: string
          created_at: string | null
          edited_at: string | null
          id: string
          images: string[] | null
          is_edited: boolean | null
          is_pinned: boolean | null
          likes_count: number | null
          shares_count: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          comments_count?: number | null
          community_id?: string | null
          content: string
          created_at?: string | null
          edited_at?: string | null
          id?: string
          images?: string[] | null
          is_edited?: boolean | null
          is_pinned?: boolean | null
          likes_count?: number | null
          shares_count?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          comments_count?: number | null
          community_id?: string | null
          content?: string
          created_at?: string | null
          edited_at?: string | null
          id?: string
          images?: string[] | null
          is_edited?: boolean | null
          is_pinned?: boolean | null
          likes_count?: number | null
          shares_count?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_posts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      network_stories: {
        Row: {
          created_at: string | null
          duration: number | null
          expires_at: string | null
          id: string
          image_url: string
          is_active: boolean | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          duration?: number | null
          expires_at?: string | null
          id?: string
          image_url: string
          is_active?: boolean | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          duration?: number | null
          expires_at?: string | null
          id?: string
          image_url?: string
          is_active?: boolean | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "network_stories_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      news_article_hashtags: {
        Row: {
          article_id: string
          hashtag_id: string
        }
        Insert: {
          article_id: string
          hashtag_id: string
        }
        Update: {
          article_id?: string
          hashtag_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_article_hashtags_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_article_hashtags_hashtag_id_fkey"
            columns: ["hashtag_id"]
            isOneToOne: false
            referencedRelation: "news_hashtags"
            referencedColumns: ["id"]
          },
        ]
      }
      news_articles: {
        Row: {
          category: string
          content: string
          created_at: string | null
          created_by: string | null
          id: string
          image_url: string | null
          is_breaking: boolean | null
          is_featured: boolean | null
          likes_count: number | null
          published_at: string | null
          shares_count: number | null
          status: string | null
          summary: string | null
          title: string
          updated_at: string | null
          video_url: string | null
          views_count: number | null
        }
        Insert: {
          category: string
          content: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          image_url?: string | null
          is_breaking?: boolean | null
          is_featured?: boolean | null
          likes_count?: number | null
          published_at?: string | null
          shares_count?: number | null
          status?: string | null
          summary?: string | null
          title: string
          updated_at?: string | null
          video_url?: string | null
          views_count?: number | null
        }
        Update: {
          category?: string
          content?: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          image_url?: string | null
          is_breaking?: boolean | null
          is_featured?: boolean | null
          likes_count?: number | null
          published_at?: string | null
          shares_count?: number | null
          status?: string | null
          summary?: string | null
          title?: string
          updated_at?: string | null
          video_url?: string | null
          views_count?: number | null
        }
        Relationships: []
      }
      news_categories: {
        Row: {
          color: string | null
          created_at: string | null
          display_order: number | null
          icon: string | null
          id: string
          name: string
          slug: string
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          display_order?: number | null
          icon?: string | null
          id?: string
          name: string
          slug: string
        }
        Update: {
          color?: string | null
          created_at?: string | null
          display_order?: number | null
          icon?: string | null
          id?: string
          name?: string
          slug?: string
        }
        Relationships: []
      }
      news_comments: {
        Row: {
          article_id: string | null
          content: string
          created_at: string | null
          id: string
          likes_count: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          article_id?: string | null
          content: string
          created_at?: string | null
          id?: string
          likes_count?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          article_id?: string | null
          content?: string
          created_at?: string | null
          id?: string
          likes_count?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_comments_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
        ]
      }
      news_hashtags: {
        Row: {
          created_at: string | null
          id: string
          name: string
          usage_count: number | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          name: string
          usage_count?: number | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string
          usage_count?: number | null
        }
        Relationships: []
      }
      news_likes: {
        Row: {
          article_id: string | null
          created_at: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          article_id?: string | null
          created_at?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          article_id?: string | null
          created_at?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_likes_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
        ]
      }
      news_notifications: {
        Row: {
          article_id: string | null
          created_at: string | null
          id: string
          is_read: boolean | null
          message: string | null
          read_at: string | null
          title: string
          type: string
          user_id: string | null
        }
        Insert: {
          article_id?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          message?: string | null
          read_at?: string | null
          title: string
          type: string
          user_id?: string | null
        }
        Update: {
          article_id?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          message?: string | null
          read_at?: string | null
          title?: string
          type?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_notifications_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
        ]
      }
      news_reports: {
        Row: {
          article_id: string | null
          created_at: string | null
          id: string
          reason: string
          resolved_at: string | null
          resolved_by: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          article_id?: string | null
          created_at?: string | null
          id?: string
          reason: string
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          article_id?: string | null
          created_at?: string | null
          id?: string
          reason?: string
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_reports_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
        ]
      }
      news_saved: {
        Row: {
          article_id: string | null
          id: string
          saved_at: string | null
          user_id: string | null
        }
        Insert: {
          article_id?: string | null
          id?: string
          saved_at?: string | null
          user_id?: string | null
        }
        Update: {
          article_id?: string | null
          id?: string
          saved_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_saved_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
        ]
      }
      news_shares: {
        Row: {
          article_id: string | null
          id: string
          platform: string | null
          shared_at: string | null
          user_id: string | null
        }
        Insert: {
          article_id?: string | null
          id?: string
          platform?: string | null
          shared_at?: string | null
          user_id?: string | null
        }
        Update: {
          article_id?: string | null
          id?: string
          platform?: string | null
          shared_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_shares_article_id_fkey"
            columns: ["article_id"]
            isOneToOne: false
            referencedRelation: "news_articles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          content: string | null
          created_at: string | null
          id: string
          is_read: boolean | null
          type: string | null
          user_id: string | null
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          type?: string | null
          user_id?: string | null
        }
        Update: {
          content?: string | null
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          type?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      operations: {
        Row: {
          created_at: string
          id: string
          notes: string | null
          patient_id: string
          patient_name: string
          postop_report: Json | null
          preop_checklist: Json | null
          room: string
          scheduled_date: string
          status: string | null
          surgeon_id: string | null
          surgeon_name: string
          type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          notes?: string | null
          patient_id: string
          patient_name: string
          postop_report?: Json | null
          preop_checklist?: Json | null
          room: string
          scheduled_date: string
          status?: string | null
          surgeon_id?: string | null
          surgeon_name: string
          type: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          notes?: string | null
          patient_id?: string
          patient_name?: string
          postop_report?: Json | null
          preop_checklist?: Json | null
          room?: string
          scheduled_date?: string
          status?: string | null
          surgeon_id?: string | null
          surgeon_name?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "operations_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "operations_surgeon_id_fkey"
            columns: ["surgeon_id"]
            isOneToOne: false
            referencedRelation: "doctors"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          color: string | null
          created_at: string | null
          id: string
          order_id: string
          price: number
          product_id: string | null
          product_image: string | null
          product_name: string | null
          quantity: number
          variant: string | null
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          id?: string
          order_id: string
          price: number
          product_id?: string | null
          product_image?: string | null
          product_name?: string | null
          quantity: number
          variant?: string | null
        }
        Update: {
          color?: string | null
          created_at?: string | null
          id?: string
          order_id?: string
          price?: number
          product_id?: string | null
          product_image?: string | null
          product_name?: string | null
          quantity?: number
          variant?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          address_id: string | null
          cancelled_at: string | null
          created_at: string | null
          delivered_at: string | null
          id: string
          paid_at: string | null
          payment_method: string | null
          payment_status: string | null
          shipped_at: string | null
          shipping_cost: number | null
          shipping_method: string | null
          shop_id: string | null
          status: string | null
          total: number
          tracking_number: string | null
          transaction_id: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          address_id?: string | null
          cancelled_at?: string | null
          created_at?: string | null
          delivered_at?: string | null
          id?: string
          paid_at?: string | null
          payment_method?: string | null
          payment_status?: string | null
          shipped_at?: string | null
          shipping_cost?: number | null
          shipping_method?: string | null
          shop_id?: string | null
          status?: string | null
          total: number
          tracking_number?: string | null
          transaction_id?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          address_id?: string | null
          cancelled_at?: string | null
          created_at?: string | null
          delivered_at?: string | null
          id?: string
          paid_at?: string | null
          payment_method?: string | null
          payment_status?: string | null
          shipped_at?: string | null
          shipping_cost?: number | null
          shipping_method?: string | null
          shop_id?: string | null
          status?: string | null
          total?: number
          tracking_number?: string | null
          transaction_id?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "orders_address_id_fkey"
            columns: ["address_id"]
            isOneToOne: false
            referencedRelation: "addresses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      origin: {
        Row: {
          father_name: string | null
          id: string
          mother_name: string | null
          province: string | null
          sector: string | null
          territory: string | null
          user_id: string | null
        }
        Insert: {
          father_name?: string | null
          id?: string
          mother_name?: string | null
          province?: string | null
          sector?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Update: {
          father_name?: string | null
          id?: string
          mother_name?: string | null
          province?: string | null
          sector?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "origin_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_records: {
        Row: {
          created_at: string | null
          description: string | null
          file_url: string | null
          id: string
          patient_id: string
          record_date: string
          record_type: string
          title: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          file_url?: string | null
          id?: string
          patient_id: string
          record_date: string
          record_type: string
          title: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          file_url?: string | null
          id?: string
          patient_id?: string
          record_date?: string
          record_type?: string
          title?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      patients: {
        Row: {
          address: string | null
          allergies: string[] | null
          birth_date: string
          blood_type: string | null
          created_at: string
          emergency_contact: string | null
          gender: Database["public"]["Enums"]["gender_enum"]
          hospital_id: string
          id: string
          profile_id: string
          status: Database["public"]["Enums"]["status_enum"] | null
          thix_id: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          allergies?: string[] | null
          birth_date: string
          blood_type?: string | null
          created_at?: string
          emergency_contact?: string | null
          gender?: Database["public"]["Enums"]["gender_enum"]
          hospital_id: string
          id?: string
          profile_id: string
          status?: Database["public"]["Enums"]["status_enum"] | null
          thix_id?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          allergies?: string[] | null
          birth_date?: string
          blood_type?: string | null
          created_at?: string
          emergency_contact?: string | null
          gender?: Database["public"]["Enums"]["gender_enum"]
          hospital_id?: string
          id?: string
          profile_id?: string
          status?: Database["public"]["Enums"]["status_enum"] | null
          thix_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "patients_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number | null
          created_at: string | null
          id: string
          provider: string | null
          status: string | null
          transaction_id: string
          user_id: string
        }
        Insert: {
          amount?: number | null
          created_at?: string | null
          id?: string
          provider?: string | null
          status?: string | null
          transaction_id: string
          user_id: string
        }
        Update: {
          amount?: number | null
          created_at?: string | null
          id?: string
          provider?: string | null
          status?: string | null
          transaction_id?: string
          user_id?: string
        }
        Relationships: []
      }
      permission_scopes: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: number
          name: string
        }
        Update: {
          id?: number
          name?: string
        }
        Relationships: []
      }
      permissions: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: number
          name: string
        }
        Update: {
          id?: number
          name?: string
        }
        Relationships: []
      }
      pharmacies: {
        Row: {
          address: string
          created_at: string
          email: string | null
          id: string
          name: string
          opening_hours: string | null
          phone: string | null
          profile_id: string
          siret: string | null
          updated_at: string
        }
        Insert: {
          address: string
          created_at?: string
          email?: string | null
          id?: string
          name: string
          opening_hours?: string | null
          phone?: string | null
          profile_id: string
          siret?: string | null
          updated_at?: string
        }
        Update: {
          address?: string
          created_at?: string
          email?: string | null
          id?: string
          name?: string
          opening_hours?: string | null
          phone?: string | null
          profile_id?: string
          siret?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "pharmacies_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      pickup_points: {
        Row: {
          address: string
          created_at: string | null
          id: string
          latitude: number
          longitude: number
          name: string
          opening_hours: string | null
          phone: string | null
        }
        Insert: {
          address: string
          created_at?: string | null
          id?: string
          latitude: number
          longitude: number
          name: string
          opening_hours?: string | null
          phone?: string | null
        }
        Update: {
          address?: string
          created_at?: string | null
          id?: string
          latitude?: number
          longitude?: number
          name?: string
          opening_hours?: string | null
          phone?: string | null
        }
        Relationships: []
      }
      poll_votes: {
        Row: {
          id: string
          option_index: number
          poll_id: string
          user_id: string
          voted_at: string | null
        }
        Insert: {
          id?: string
          option_index: number
          poll_id: string
          user_id: string
          voted_at?: string | null
        }
        Update: {
          id?: string
          option_index?: number
          poll_id?: string
          user_id?: string
          voted_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_poll_votes_poll"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_poll_votes_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      polls: {
        Row: {
          created_at: string | null
          end_date: string
          id: string
          options: string[]
          post_id: string | null
          question: string
          total_votes: number | null
          votes: number[] | null
        }
        Insert: {
          created_at?: string | null
          end_date: string
          id?: string
          options: string[]
          post_id?: string | null
          question: string
          total_votes?: number | null
          votes?: number[] | null
        }
        Update: {
          created_at?: string | null
          end_date?: string
          id?: string
          options?: string[]
          post_id?: string | null
          question?: string
          total_votes?: number | null
          votes?: number[] | null
        }
        Relationships: [
          {
            foreignKeyName: "polls_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      post_hashtags: {
        Row: {
          hashtag_id: string | null
          id: string
          post_id: string | null
        }
        Insert: {
          hashtag_id?: string | null
          id?: string
          post_id?: string | null
        }
        Update: {
          hashtag_id?: string | null
          id?: string
          post_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "post_hashtags_hashtag_id_fkey"
            columns: ["hashtag_id"]
            isOneToOne: false
            referencedRelation: "hashtags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_hashtags_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      post_likes: {
        Row: {
          created_at: string | null
          id: string
          post_id: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      posts: {
        Row: {
          comments_count: number | null
          content: string | null
          created_at: string | null
          id: string
          image_urls: string[] | null
          is_public: boolean | null
          likes_count: number | null
          media_type: string | null
          media_url: string | null
          user_id: string | null
        }
        Insert: {
          comments_count?: number | null
          content?: string | null
          created_at?: string | null
          id?: string
          image_urls?: string[] | null
          is_public?: boolean | null
          likes_count?: number | null
          media_type?: string | null
          media_url?: string | null
          user_id?: string | null
        }
        Update: {
          comments_count?: number | null
          content?: string | null
          created_at?: string | null
          id?: string
          image_urls?: string[] | null
          is_public?: boolean | null
          likes_count?: number | null
          media_type?: string | null
          media_url?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      prescriptions: {
        Row: {
          created_at: string
          date: string
          doctor_id: string | null
          doctor_name: string
          doctor_notes: string | null
          id: string
          items: Json
          patient_id: string
          patient_name: string
          status: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          date?: string
          doctor_id?: string | null
          doctor_name: string
          doctor_notes?: string | null
          id?: string
          items: Json
          patient_id: string
          patient_name: string
          status?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          date?: string
          doctor_id?: string | null
          doctor_name?: string
          doctor_notes?: string | null
          id?: string
          items?: Json
          patient_id?: string
          patient_name?: string
          status?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "prescriptions_doctor_id_fkey"
            columns: ["doctor_id"]
            isOneToOne: false
            referencedRelation: "doctors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prescriptions_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          boost_expires_at: string | null
          brand: string | null
          category: string | null
          condition: string | null
          created_at: string | null
          description: string | null
          discount_price: number | null
          flash_sale_end: string | null
          free_shipping: boolean | null
          id: string
          images: string[] | null
          is_boosted: boolean | null
          is_flash_sale: boolean | null
          is_service: boolean | null
          latitude: number | null
          longitude: number | null
          price: number
          rating: number | null
          reviews_count: number | null
          shipping_type: string | null
          shop_id: string
          status: string | null
          stock: number
          title: string
          updated_at: string | null
          views: number | null
        }
        Insert: {
          boost_expires_at?: string | null
          brand?: string | null
          category?: string | null
          condition?: string | null
          created_at?: string | null
          description?: string | null
          discount_price?: number | null
          flash_sale_end?: string | null
          free_shipping?: boolean | null
          id?: string
          images?: string[] | null
          is_boosted?: boolean | null
          is_flash_sale?: boolean | null
          is_service?: boolean | null
          latitude?: number | null
          longitude?: number | null
          price: number
          rating?: number | null
          reviews_count?: number | null
          shipping_type?: string | null
          shop_id: string
          status?: string | null
          stock?: number
          title: string
          updated_at?: string | null
          views?: number | null
        }
        Update: {
          boost_expires_at?: string | null
          brand?: string | null
          category?: string | null
          condition?: string | null
          created_at?: string | null
          description?: string | null
          discount_price?: number | null
          flash_sale_end?: string | null
          free_shipping?: boolean | null
          id?: string
          images?: string[] | null
          is_boosted?: boolean | null
          is_flash_sale?: boolean | null
          is_service?: boolean | null
          latitude?: number | null
          longitude?: number | null
          price?: number
          rating?: number | null
          reviews_count?: number | null
          shipping_type?: string | null
          shop_id?: string
          status?: string | null
          stock?: number
          title?: string
          updated_at?: string | null
          views?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_access_requests: {
        Row: {
          approved_until: string | null
          created_at: string | null
          id: string
          profile_id: string
          requester_id: string
          status: string | null
        }
        Insert: {
          approved_until?: string | null
          created_at?: string | null
          id?: string
          profile_id: string
          requester_id: string
          status?: string | null
        }
        Update: {
          approved_until?: string | null
          created_at?: string | null
          id?: string
          profile_id?: string
          requester_id?: string
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profile_access_requests_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          address: string | null
          avatar_url: string | null
          avenue: string | null
          bio: string | null
          bio_professional: string | null
          birth_date: string | null
          birth_place: string | null
          blood_group: string | null
          city: string | null
          commune: string | null
          commune_residence: string | null
          company_name: string | null
          competence: string | null
          contact_phone: string | null
          country_or_origin: string | null
          created_at: string | null
          current_avenue: string | null
          current_city: string | null
          current_commune: string | null
          current_country: string | null
          current_house_number: string | null
          current_neighborhood: string | null
          current_number: string | null
          current_province: string | null
          current_province_id: number | null
          current_residence_country: string | null
          current_territory: string | null
          current_territory_id: number | null
          date_emission_piece: string | null
          date_expiration_piece: string | null
          date_of_birth: string | null
          disability: string | null
          display_name: string | null
          document_type: string | null
          education: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          emergency_contact_relation: string | null
          emergency_contacts: Json | null
          experience: string | null
          expiry_date: string | null
          father_name: string | null
          full_name: string | null
          gender: string | null
          groupe_sanguin: string | null
          handicap_physique: boolean | null
          has_physical_disability: boolean | null
          height: string | null
          height_cm: number | null
          id: string
          id_document_expiry_date: string | null
          id_document_issue_date: string | null
          id_document_issue_place: string | null
          id_document_type: string | null
          id_expiry_date: string | null
          id_issue_date: string | null
          id_issue_place: string | null
          id_type: string | null
          is_active: boolean | null
          is_private: boolean | null
          is_verified: boolean | null
          issue_date: string | null
          issue_place: string | null
          job_title: string | null
          languages: string[] | null
          last_diploma: string | null
          last_name: string | null
          lieu_emission_piece: string | null
          location: string | null
          main_missions: string | null
          marital_status: string | null
          mother_name: string | null
          national_id: string | null
          national_id_number: string | null
          nationality: string | null
          notification_settings: Json | null
          numero_id_national: string | null
          numero_maison: string | null
          numero_residence: string | null
          occupation: string | null
          origin_country: string | null
          origin_province: string | null
          origin_province_id: number | null
          origin_sector: string | null
          origin_territory: string | null
          origin_territory_id: number | null
          payment_status: string | null
          pays: string | null
          pays_residence: string | null
          phone_number: string | null
          photo_url: string | null
          physical_handicap: boolean | null
          place_of_birth: string | null
          poids_kg: number | null
          privacy_settings: Json | null
          profession: string | null
          province: string | null
          province_origine: string | null
          province_residence: string | null
          quartier: string | null
          res_avenue: string | null
          res_commune: string | null
          res_numero: string | null
          res_pays: string | null
          res_province: string | null
          res_quartier: string | null
          res_territoire: string | null
          res_ville: string | null
          residence_avenue: string | null
          residence_city: string | null
          residence_commune: string | null
          residence_country: string | null
          residence_number: string | null
          residence_province: string | null
          residence_quarter: string | null
          residence_territory: string | null
          role: string | null
          secteur_origine: string | null
          sector: string | null
          skills: string[] | null
          skills_summary: string | null
          study_city: string | null
          study_end_year: string | null
          study_start_year: string | null
          subscription_status: string | null
          taille_cm: number | null
          territoire: string | null
          territoire_origine: string | null
          thix_chat: boolean | null
          thix_chat_handle: string | null
          thix_email_phone: string | null
          thix_id: string | null
          thix_uid: string | null
          title: string | null
          trial_ends_at: string | null
          trial_started_at: string | null
          type_piece_identite: string | null
          university_name: string | null
          updated_at: string | null
          urgence_lien: string | null
          urgence_nom: string | null
          urgence_tel: string | null
          urgence_telephone: string | null
          verification_level: string | null
          ville: string | null
          ville_residence: string | null
          weight: string | null
          weight_kg: number | null
        }
        Insert: {
          address?: string | null
          avatar_url?: string | null
          avenue?: string | null
          bio?: string | null
          bio_professional?: string | null
          birth_date?: string | null
          birth_place?: string | null
          blood_group?: string | null
          city?: string | null
          commune?: string | null
          commune_residence?: string | null
          company_name?: string | null
          competence?: string | null
          contact_phone?: string | null
          country_or_origin?: string | null
          created_at?: string | null
          current_avenue?: string | null
          current_city?: string | null
          current_commune?: string | null
          current_country?: string | null
          current_house_number?: string | null
          current_neighborhood?: string | null
          current_number?: string | null
          current_province?: string | null
          current_province_id?: number | null
          current_residence_country?: string | null
          current_territory?: string | null
          current_territory_id?: number | null
          date_emission_piece?: string | null
          date_expiration_piece?: string | null
          date_of_birth?: string | null
          disability?: string | null
          display_name?: string | null
          document_type?: string | null
          education?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          emergency_contact_relation?: string | null
          emergency_contacts?: Json | null
          experience?: string | null
          expiry_date?: string | null
          father_name?: string | null
          full_name?: string | null
          gender?: string | null
          groupe_sanguin?: string | null
          handicap_physique?: boolean | null
          has_physical_disability?: boolean | null
          height?: string | null
          height_cm?: number | null
          id?: string
          id_document_expiry_date?: string | null
          id_document_issue_date?: string | null
          id_document_issue_place?: string | null
          id_document_type?: string | null
          id_expiry_date?: string | null
          id_issue_date?: string | null
          id_issue_place?: string | null
          id_type?: string | null
          is_active?: boolean | null
          is_private?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issue_place?: string | null
          job_title?: string | null
          languages?: string[] | null
          last_diploma?: string | null
          last_name?: string | null
          lieu_emission_piece?: string | null
          location?: string | null
          main_missions?: string | null
          marital_status?: string | null
          mother_name?: string | null
          national_id?: string | null
          national_id_number?: string | null
          nationality?: string | null
          notification_settings?: Json | null
          numero_id_national?: string | null
          numero_maison?: string | null
          numero_residence?: string | null
          occupation?: string | null
          origin_country?: string | null
          origin_province?: string | null
          origin_province_id?: number | null
          origin_sector?: string | null
          origin_territory?: string | null
          origin_territory_id?: number | null
          payment_status?: string | null
          pays?: string | null
          pays_residence?: string | null
          phone_number?: string | null
          photo_url?: string | null
          physical_handicap?: boolean | null
          place_of_birth?: string | null
          poids_kg?: number | null
          privacy_settings?: Json | null
          profession?: string | null
          province?: string | null
          province_origine?: string | null
          province_residence?: string | null
          quartier?: string | null
          res_avenue?: string | null
          res_commune?: string | null
          res_numero?: string | null
          res_pays?: string | null
          res_province?: string | null
          res_quartier?: string | null
          res_territoire?: string | null
          res_ville?: string | null
          residence_avenue?: string | null
          residence_city?: string | null
          residence_commune?: string | null
          residence_country?: string | null
          residence_number?: string | null
          residence_province?: string | null
          residence_quarter?: string | null
          residence_territory?: string | null
          role?: string | null
          secteur_origine?: string | null
          sector?: string | null
          skills?: string[] | null
          skills_summary?: string | null
          study_city?: string | null
          study_end_year?: string | null
          study_start_year?: string | null
          subscription_status?: string | null
          taille_cm?: number | null
          territoire?: string | null
          territoire_origine?: string | null
          thix_chat?: boolean | null
          thix_chat_handle?: string | null
          thix_email_phone?: string | null
          thix_id?: string | null
          thix_uid?: string | null
          title?: string | null
          trial_ends_at?: string | null
          trial_started_at?: string | null
          type_piece_identite?: string | null
          university_name?: string | null
          updated_at?: string | null
          urgence_lien?: string | null
          urgence_nom?: string | null
          urgence_tel?: string | null
          urgence_telephone?: string | null
          verification_level?: string | null
          ville?: string | null
          ville_residence?: string | null
          weight?: string | null
          weight_kg?: number | null
        }
        Update: {
          address?: string | null
          avatar_url?: string | null
          avenue?: string | null
          bio?: string | null
          bio_professional?: string | null
          birth_date?: string | null
          birth_place?: string | null
          blood_group?: string | null
          city?: string | null
          commune?: string | null
          commune_residence?: string | null
          company_name?: string | null
          competence?: string | null
          contact_phone?: string | null
          country_or_origin?: string | null
          created_at?: string | null
          current_avenue?: string | null
          current_city?: string | null
          current_commune?: string | null
          current_country?: string | null
          current_house_number?: string | null
          current_neighborhood?: string | null
          current_number?: string | null
          current_province?: string | null
          current_province_id?: number | null
          current_residence_country?: string | null
          current_territory?: string | null
          current_territory_id?: number | null
          date_emission_piece?: string | null
          date_expiration_piece?: string | null
          date_of_birth?: string | null
          disability?: string | null
          display_name?: string | null
          document_type?: string | null
          education?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          emergency_contact_relation?: string | null
          emergency_contacts?: Json | null
          experience?: string | null
          expiry_date?: string | null
          father_name?: string | null
          full_name?: string | null
          gender?: string | null
          groupe_sanguin?: string | null
          handicap_physique?: boolean | null
          has_physical_disability?: boolean | null
          height?: string | null
          height_cm?: number | null
          id?: string
          id_document_expiry_date?: string | null
          id_document_issue_date?: string | null
          id_document_issue_place?: string | null
          id_document_type?: string | null
          id_expiry_date?: string | null
          id_issue_date?: string | null
          id_issue_place?: string | null
          id_type?: string | null
          is_active?: boolean | null
          is_private?: boolean | null
          is_verified?: boolean | null
          issue_date?: string | null
          issue_place?: string | null
          job_title?: string | null
          languages?: string[] | null
          last_diploma?: string | null
          last_name?: string | null
          lieu_emission_piece?: string | null
          location?: string | null
          main_missions?: string | null
          marital_status?: string | null
          mother_name?: string | null
          national_id?: string | null
          national_id_number?: string | null
          nationality?: string | null
          notification_settings?: Json | null
          numero_id_national?: string | null
          numero_maison?: string | null
          numero_residence?: string | null
          occupation?: string | null
          origin_country?: string | null
          origin_province?: string | null
          origin_province_id?: number | null
          origin_sector?: string | null
          origin_territory?: string | null
          origin_territory_id?: number | null
          payment_status?: string | null
          pays?: string | null
          pays_residence?: string | null
          phone_number?: string | null
          photo_url?: string | null
          physical_handicap?: boolean | null
          place_of_birth?: string | null
          poids_kg?: number | null
          privacy_settings?: Json | null
          profession?: string | null
          province?: string | null
          province_origine?: string | null
          province_residence?: string | null
          quartier?: string | null
          res_avenue?: string | null
          res_commune?: string | null
          res_numero?: string | null
          res_pays?: string | null
          res_province?: string | null
          res_quartier?: string | null
          res_territoire?: string | null
          res_ville?: string | null
          residence_avenue?: string | null
          residence_city?: string | null
          residence_commune?: string | null
          residence_country?: string | null
          residence_number?: string | null
          residence_province?: string | null
          residence_quarter?: string | null
          residence_territory?: string | null
          role?: string | null
          secteur_origine?: string | null
          sector?: string | null
          skills?: string[] | null
          skills_summary?: string | null
          study_city?: string | null
          study_end_year?: string | null
          study_start_year?: string | null
          subscription_status?: string | null
          taille_cm?: number | null
          territoire?: string | null
          territoire_origine?: string | null
          thix_chat?: boolean | null
          thix_chat_handle?: string | null
          thix_email_phone?: string | null
          thix_id?: string | null
          thix_uid?: string | null
          title?: string | null
          trial_ends_at?: string | null
          trial_started_at?: string | null
          type_piece_identite?: string | null
          university_name?: string | null
          updated_at?: string | null
          urgence_lien?: string | null
          urgence_nom?: string | null
          urgence_tel?: string | null
          urgence_telephone?: string | null
          verification_level?: string | null
          ville?: string | null
          ville_residence?: string | null
          weight?: string | null
          weight_kg?: number | null
        }
        Relationships: []
      }
      promo_banners: {
        Row: {
          created_at: string | null
          id: string
          image_url: string
          is_active: boolean | null
          link: string | null
          sort_order: number | null
          title: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          image_url: string
          is_active?: boolean | null
          link?: string | null
          sort_order?: number | null
          title?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          image_url?: string
          is_active?: boolean | null
          link?: string | null
          sort_order?: number | null
          title?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      promo_code_usages: {
        Row: {
          id: string
          promo_code_id: string
          transaction_id: string | null
          used_at: string
          user_id: string
        }
        Insert: {
          id?: string
          promo_code_id: string
          transaction_id?: string | null
          used_at?: string
          user_id: string
        }
        Update: {
          id?: string
          promo_code_id?: string
          transaction_id?: string | null
          used_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promo_code_usages_promo_code_id_fkey"
            columns: ["promo_code_id"]
            isOneToOne: false
            referencedRelation: "promo_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promo_code_usages_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      promo_codes: {
        Row: {
          code: string
          created_at: string | null
          discount_percent: number
          event_id: string | null
          id: string
          is_active: boolean | null
          valid_until: string
        }
        Insert: {
          code: string
          created_at?: string | null
          discount_percent: number
          event_id?: string | null
          id?: string
          is_active?: boolean | null
          valid_until: string
        }
        Update: {
          code?: string
          created_at?: string | null
          discount_percent?: number
          event_id?: string | null
          id?: string
          is_active?: boolean | null
          valid_until?: string
        }
        Relationships: []
      }
      promotions: {
        Row: {
          code: string
          created_at: string | null
          discount_type: string | null
          discount_value: number
          end_date: string
          id: string
          is_active: boolean | null
          name: string
          start_date: string
          updated_at: string | null
        }
        Insert: {
          code: string
          created_at?: string | null
          discount_type?: string | null
          discount_value: number
          end_date: string
          id?: string
          is_active?: boolean | null
          name: string
          start_date: string
          updated_at?: string | null
        }
        Update: {
          code?: string
          created_at?: string | null
          discount_type?: string | null
          discount_value?: number
          end_date?: string
          id?: string
          is_active?: boolean | null
          name?: string
          start_date?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      provinces: {
        Row: {
          id: string
          name: string
        }
        Insert: {
          id?: string
          name: string
        }
        Update: {
          id?: string
          name?: string
        }
        Relationships: []
      }
      push_tokens: {
        Row: {
          created_at: string | null
          id: string
          last_seen_at: string | null
          platform: string
          token: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          last_seen_at?: string | null
          platform: string
          token: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          last_seen_at?: string | null
          platform?: string
          token?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      quiz_questions: {
        Row: {
          correct_option_index: number
          created_at: string | null
          explanation: string | null
          id: string
          lesson_id: string | null
          options: string[]
          question: string
        }
        Insert: {
          correct_option_index: number
          created_at?: string | null
          explanation?: string | null
          id?: string
          lesson_id?: string | null
          options: string[]
          question: string
        }
        Update: {
          correct_option_index?: number
          created_at?: string | null
          explanation?: string | null
          id?: string
          lesson_id?: string | null
          options?: string[]
          question?: string
        }
        Relationships: [
          {
            foreignKeyName: "quiz_questions_lesson_id_fkey"
            columns: ["lesson_id"]
            isOneToOne: false
            referencedRelation: "training_lessons"
            referencedColumns: ["id"]
          },
        ]
      }
      read_receipts: {
        Row: {
          id: string
          message_id: string
          read_at: string | null
          user_id: string
        }
        Insert: {
          id?: string
          message_id: string
          read_at?: string | null
          user_id: string
        }
        Update: {
          id?: string
          message_id?: string
          read_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_read_receipts_message"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_read_receipts_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      reel_likes: {
        Row: {
          created_at: string | null
          id: string
          reel_id: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          reel_id?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          reel_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reel_likes_reel_id_fkey"
            columns: ["reel_id"]
            isOneToOne: false
            referencedRelation: "reels"
            referencedColumns: ["id"]
          },
        ]
      }
      reels: {
        Row: {
          caption: string | null
          comments_count: number | null
          created_at: string | null
          duration: number | null
          id: string
          likes_count: number | null
          music_name: string | null
          shares_count: number | null
          thumbnail_url: string | null
          user_id: string | null
          video_url: string
        }
        Insert: {
          caption?: string | null
          comments_count?: number | null
          created_at?: string | null
          duration?: number | null
          id?: string
          likes_count?: number | null
          music_name?: string | null
          shares_count?: number | null
          thumbnail_url?: string | null
          user_id?: string | null
          video_url: string
        }
        Update: {
          caption?: string | null
          comments_count?: number | null
          created_at?: string | null
          duration?: number | null
          id?: string
          likes_count?: number | null
          music_name?: string | null
          shares_count?: number | null
          thumbnail_url?: string | null
          user_id?: string | null
          video_url?: string
        }
        Relationships: []
      }
      reported_posts: {
        Row: {
          id: string
          post_id: string | null
          reason: string | null
          reported_at: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          id?: string
          post_id?: string | null
          reason?: string | null
          reported_at?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          id?: string
          post_id?: string | null
          reason?: string | null
          reported_at?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reported_posts_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "network_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string | null
          id: string
          reason: string | null
          reported_user_id: string | null
          reporter_id: string
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          reason?: string | null
          reported_user_id?: string | null
          reporter_id: string
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          reason?: string | null
          reported_user_id?: string | null
          reporter_id?: string
          status?: string | null
        }
        Relationships: []
      }
      reposts: {
        Row: {
          created_at: string | null
          id: string
          original_post_id: string | null
          quote: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          original_post_id?: string | null
          quote?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          original_post_id?: string | null
          quote?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reposts_original_post_id_fkey"
            columns: ["original_post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      reservations: {
        Row: {
          code: string
          created_at: string | null
          date_fin: string | null
          date_reservation: string | null
          date_service: string
          description: string | null
          details: Json | null
          devise: string | null
          id: string
          image_url: string | null
          montant: number
          status: string | null
          titre: string
          type: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          code: string
          created_at?: string | null
          date_fin?: string | null
          date_reservation?: string | null
          date_service: string
          description?: string | null
          details?: Json | null
          devise?: string | null
          id?: string
          image_url?: string | null
          montant: number
          status?: string | null
          titre: string
          type: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          code?: string
          created_at?: string | null
          date_fin?: string | null
          date_reservation?: string | null
          date_service?: string
          description?: string | null
          details?: Json | null
          devise?: string | null
          id?: string
          image_url?: string | null
          montant?: number
          status?: string | null
          titre?: string
          type?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      residence: {
        Row: {
          avenue: string | null
          city: string | null
          commune: string | null
          country: string | null
          district: string | null
          id: string
          number: string | null
          province: string | null
          territory: string | null
          user_id: string | null
        }
        Insert: {
          avenue?: string | null
          city?: string | null
          commune?: string | null
          country?: string | null
          district?: string | null
          id?: string
          number?: string | null
          province?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Update: {
          avenue?: string | null
          city?: string | null
          commune?: string | null
          country?: string | null
          district?: string | null
          id?: string
          number?: string | null
          province?: string | null
          territory?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "residence_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      restaurants: {
        Row: {
          adresse: string
          avis_count: number | null
          created_at: string | null
          cuisine: string
          devise: string | null
          distance_km: number | null
          est_actif: boolean | null
          frais_livraison: number | null
          horaires: string | null
          id: string
          images_url: string[] | null
          latitude: number | null
          livraison_gratuite: boolean | null
          longitude: number | null
          nom: string
          note: number | null
          prix_moyen: number
          specialites: string[] | null
          temps_livraison: string | null
          type: string
          ville: string
        }
        Insert: {
          adresse: string
          avis_count?: number | null
          created_at?: string | null
          cuisine: string
          devise?: string | null
          distance_km?: number | null
          est_actif?: boolean | null
          frais_livraison?: number | null
          horaires?: string | null
          id?: string
          images_url?: string[] | null
          latitude?: number | null
          livraison_gratuite?: boolean | null
          longitude?: number | null
          nom: string
          note?: number | null
          prix_moyen: number
          specialites?: string[] | null
          temps_livraison?: string | null
          type: string
          ville: string
        }
        Update: {
          adresse?: string
          avis_count?: number | null
          created_at?: string | null
          cuisine?: string
          devise?: string | null
          distance_km?: number | null
          est_actif?: boolean | null
          frais_livraison?: number | null
          horaires?: string | null
          id?: string
          images_url?: string[] | null
          latitude?: number | null
          livraison_gratuite?: boolean | null
          longitude?: number | null
          nom?: string
          note?: number | null
          prix_moyen?: number
          specialites?: string[] | null
          temps_livraison?: string | null
          type?: string
          ville?: string
        }
        Relationships: []
      }
      reviews: {
        Row: {
          comment: string | null
          created_at: string | null
          id: string
          images: string[] | null
          order_id: string | null
          product_id: string
          rating: number
          replied_at: string | null
          reply: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string | null
          id?: string
          images?: string[] | null
          order_id?: string | null
          product_id: string
          rating: number
          replied_at?: string | null
          reply?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string | null
          id?: string
          images?: string[] | null
          order_id?: string | null
          product_id?: string
          rating?: number
          replied_at?: string | null
          reply?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reviews_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          permission_id: number
          role_id: number
          scope_id: number
        }
        Insert: {
          permission_id: number
          role_id: number
          scope_id: number
        }
        Update: {
          permission_id?: number
          role_id?: number
          scope_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_scope_id_fkey"
            columns: ["scope_id"]
            isOneToOne: false
            referencedRelation: "permission_scopes"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: number
          name: string
        }
        Update: {
          id?: number
          name?: string
        }
        Relationships: []
      }
      saved_cards: {
        Row: {
          brand: string
          created_at: string | null
          id: string
          is_default: boolean | null
          last4: string
          payment_method_id: string
          user_id: string
        }
        Insert: {
          brand: string
          created_at?: string | null
          id?: string
          is_default?: boolean | null
          last4: string
          payment_method_id: string
          user_id: string
        }
        Update: {
          brand?: string
          created_at?: string | null
          id?: string
          is_default?: boolean | null
          last4?: string
          payment_method_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_cards_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_posts: {
        Row: {
          id: string
          post_id: string | null
          saved_at: string | null
          user_id: string | null
        }
        Insert: {
          id?: string
          post_id?: string | null
          saved_at?: string | null
          user_id?: string | null
        }
        Update: {
          id?: string
          post_id?: string | null
          saved_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "saved_posts_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_contributions: {
        Row: {
          amount: number
          created_at: string
          goal_id: string
          id: string
          transaction_id: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          goal_id: string
          id?: string
          transaction_id?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          goal_id?: string
          id?: string
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "savings_contributions_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "savings_goals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "savings_contributions_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_goals: {
        Row: {
          created_at: string
          current_amount: number
          deadline: string
          icon: string | null
          id: string
          monthly_contribution: number | null
          name: string
          status: string
          target_amount: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          current_amount?: number
          deadline: string
          icon?: string | null
          id?: string
          monthly_contribution?: number | null
          name: string
          status?: string
          target_amount: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          current_amount?: number
          deadline?: string
          icon?: string | null
          id?: string
          monthly_contribution?: number | null
          name?: string
          status?: string
          target_amount?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      scheduled_messages: {
        Row: {
          content: string
          conversation_id: string
          created_at: string | null
          id: string
          is_recurring: boolean | null
          scheduled_at: string
          status: string | null
          user_id: string
        }
        Insert: {
          content: string
          conversation_id: string
          created_at?: string | null
          id?: string
          is_recurring?: boolean | null
          scheduled_at: string
          status?: string | null
          user_id: string
        }
        Update: {
          content?: string
          conversation_id?: string
          created_at?: string | null
          id?: string
          is_recurring?: boolean | null
          scheduled_at?: string
          status?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_scheduled_conversation"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_scheduled_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      search_history: {
        Row: {
          id: string
          query: string
          searched_at: string | null
          user_id: string
        }
        Insert: {
          id?: string
          query: string
          searched_at?: string | null
          user_id: string
        }
        Update: {
          id?: string
          query?: string
          searched_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "search_history_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      service_bookings: {
        Row: {
          booking_date: string
          booking_time: string
          created_at: string | null
          id: string
          product_id: string
          shop_id: string
          status: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          booking_date: string
          booking_time: string
          created_at?: string | null
          id?: string
          product_id: string
          shop_id: string
          status?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          booking_date?: string
          booking_time?: string
          created_at?: string | null
          id?: string
          product_id?: string
          shop_id?: string
          status?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_bookings_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_bookings_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_bookings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_followers: {
        Row: {
          created_at: string | null
          id: string
          shop_id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          shop_id: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          shop_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_followers_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_followers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      shops: {
        Row: {
          address: string | null
          category: string | null
          cover_url: string | null
          created_at: string | null
          description: string | null
          email: string | null
          followers_count: number | null
          id: string
          is_featured: boolean | null
          is_verified: boolean | null
          latitude: number | null
          logo_url: string | null
          longitude: number | null
          name: string
          owner_id: string
          phone: string | null
          products_count: number | null
          rating: number | null
          slug: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          address?: string | null
          category?: string | null
          cover_url?: string | null
          created_at?: string | null
          description?: string | null
          email?: string | null
          followers_count?: number | null
          id?: string
          is_featured?: boolean | null
          is_verified?: boolean | null
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          name: string
          owner_id: string
          phone?: string | null
          products_count?: number | null
          rating?: number | null
          slug?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string | null
          category?: string | null
          cover_url?: string | null
          created_at?: string | null
          description?: string | null
          email?: string | null
          followers_count?: number | null
          id?: string
          is_featured?: boolean | null
          is_verified?: boolean | null
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          name?: string
          owner_id?: string
          phone?: string | null
          products_count?: number | null
          rating?: number | null
          slug?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "shops_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      skills: {
        Row: {
          id: string
          is_public: boolean | null
          level: string | null
          skill_name: string | null
          user_id: string | null
        }
        Insert: {
          id?: string
          is_public?: boolean | null
          level?: string | null
          skill_name?: string | null
          user_id?: string | null
        }
        Update: {
          id?: string
          is_public?: boolean | null
          level?: string | null
          skill_name?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "skills_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      social_connections: {
        Row: {
          addressee_id: string
          created_at: string
          requester_id: string
          status: string
          updated_at: string
        }
        Insert: {
          addressee_id: string
          created_at?: string
          requester_id: string
          status: string
          updated_at?: string
        }
        Update: {
          addressee_id?: string
          created_at?: string
          requester_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      social_post_bookmarks: {
        Row: {
          created_at: string
          post_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "social_post_bookmarks_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "social_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      social_post_comments: {
        Row: {
          author_avatar_url: string | null
          author_id: string
          author_name: string
          author_role: string
          created_at: string
          id: string
          post_id: string
          text: string
        }
        Insert: {
          author_avatar_url?: string | null
          author_id: string
          author_name: string
          author_role: string
          created_at?: string
          id?: string
          post_id: string
          text: string
        }
        Update: {
          author_avatar_url?: string | null
          author_id?: string
          author_name?: string
          author_role?: string
          created_at?: string
          id?: string
          post_id?: string
          text?: string
        }
        Relationships: [
          {
            foreignKeyName: "social_post_comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "social_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      social_post_likes: {
        Row: {
          created_at: string
          post_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "social_post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "social_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      social_posts: {
        Row: {
          author_avatar_url: string | null
          author_id: string
          author_is_verified: boolean
          author_mutual_connections: number
          author_name: string
          author_role: string
          challenge: Json | null
          comment_count: number
          community_name: string | null
          content: string
          created_at: string
          hashtags: string[]
          id: string
          is_pinned: boolean
          kind: string
          like_count: number
          media_urls: string[]
          mentions: string[]
          poll: Json | null
          quote: string | null
          repost_author_name: string | null
          repost_of_post_id: string | null
          share_count: number
          updated_at: string
          view_count: number
          visibility: string
        }
        Insert: {
          author_avatar_url?: string | null
          author_id: string
          author_is_verified?: boolean
          author_mutual_connections?: number
          author_name: string
          author_role: string
          challenge?: Json | null
          comment_count?: number
          community_name?: string | null
          content: string
          created_at?: string
          hashtags?: string[]
          id?: string
          is_pinned?: boolean
          kind?: string
          like_count?: number
          media_urls?: string[]
          mentions?: string[]
          poll?: Json | null
          quote?: string | null
          repost_author_name?: string | null
          repost_of_post_id?: string | null
          share_count?: number
          updated_at?: string
          view_count?: number
          visibility?: string
        }
        Update: {
          author_avatar_url?: string | null
          author_id?: string
          author_is_verified?: boolean
          author_mutual_connections?: number
          author_name?: string
          author_role?: string
          challenge?: Json | null
          comment_count?: number
          community_name?: string | null
          content?: string
          created_at?: string
          hashtags?: string[]
          id?: string
          is_pinned?: boolean
          kind?: string
          like_count?: number
          media_urls?: string[]
          mentions?: string[]
          poll?: Json | null
          quote?: string | null
          repost_author_name?: string | null
          repost_of_post_id?: string | null
          share_count?: number
          updated_at?: string
          view_count?: number
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "social_posts_repost_of_post_id_fkey"
            columns: ["repost_of_post_id"]
            isOneToOne: false
            referencedRelation: "social_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      social_profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string
          headline: string
          updated_at: string
          user_id: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name: string
          headline?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string
          headline?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      social_stories: {
        Row: {
          author_avatar_url: string | null
          author_id: string
          author_name: string
          author_role: string
          created_at: string
          expires_at: string
          id: string
          is_video: boolean
          media_url: string | null
        }
        Insert: {
          author_avatar_url?: string | null
          author_id: string
          author_name: string
          author_role: string
          created_at?: string
          expires_at: string
          id?: string
          is_video?: boolean
          media_url?: string | null
        }
        Update: {
          author_avatar_url?: string | null
          author_id?: string
          author_name?: string
          author_role?: string
          created_at?: string
          expires_at?: string
          id?: string
          is_video?: boolean
          media_url?: string | null
        }
        Relationships: []
      }
      social_story_views: {
        Row: {
          created_at: string
          story_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          story_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          story_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "social_story_views_story_id_fkey"
            columns: ["story_id"]
            isOneToOne: false
            referencedRelation: "social_stories"
            referencedColumns: ["id"]
          },
        ]
      }
      sos_alerts: {
        Row: {
          created_at: string | null
          id: string
          location_lat: number | null
          location_long: number | null
          severity_level: number | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          location_lat?: number | null
          location_long?: number | null
          severity_level?: number | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          location_lat?: number | null
          location_long?: number | null
          severity_level?: number | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      spatial_ref_sys: {
        Row: {
          auth_name: string | null
          auth_srid: number | null
          proj4text: string | null
          srid: number
          srtext: string | null
        }
        Insert: {
          auth_name?: string | null
          auth_srid?: number | null
          proj4text?: string | null
          srid: number
          srtext?: string | null
        }
        Update: {
          auth_name?: string | null
          auth_srid?: number | null
          proj4text?: string | null
          srid?: number
          srtext?: string | null
        }
        Relationships: []
      }
      staff: {
        Row: {
          created_at: string
          id: string
          profile_id: string
          registration_number: string | null
          role: string
          service: string | null
          specialty: string
          status: Database["public"]["Enums"]["status_enum"] | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          profile_id: string
          registration_number?: string | null
          role: string
          service?: string | null
          specialty: string
          status?: Database["public"]["Enums"]["status_enum"] | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          profile_id?: string
          registration_number?: string | null
          role?: string
          service?: string | null
          specialty?: string
          status?: Database["public"]["Enums"]["status_enum"] | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      statuses: {
        Row: {
          background_color: string | null
          caption: string | null
          content_url: string | null
          created_at: string | null
          expires_at: string | null
          id: string
          type: string
          user_id: string
        }
        Insert: {
          background_color?: string | null
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          type: string
          user_id: string
        }
        Update: {
          background_color?: string | null
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      stories: {
        Row: {
          created_at: string | null
          expires_at: string
          id: string
          media_url: string
          thumbnail_url: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          expires_at: string
          id?: string
          media_url: string
          thumbnail_url?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          expires_at?: string
          id?: string
          media_url?: string
          thumbnail_url?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_stories_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      story_highlights: {
        Row: {
          cover_image: string | null
          created_at: string | null
          id: string
          name: string
          story_ids: string[] | null
          user_id: string | null
        }
        Insert: {
          cover_image?: string | null
          created_at?: string | null
          id?: string
          name: string
          story_ids?: string[] | null
          user_id?: string | null
        }
        Update: {
          cover_image?: string | null
          created_at?: string | null
          id?: string
          name?: string
          story_ids?: string[] | null
          user_id?: string | null
        }
        Relationships: []
      }
      story_views: {
        Row: {
          id: string
          story_id: string | null
          user_id: string | null
          viewed_at: string | null
        }
        Insert: {
          id?: string
          story_id?: string | null
          user_id?: string | null
          viewed_at?: string | null
        }
        Update: {
          id?: string
          story_id?: string | null
          user_id?: string | null
          viewed_at?: string | null
        }
        Relationships: []
      }
      symptoms: {
        Row: {
          created_at: string
          date: string
          id: string
          intensite: number | null
          nom: string
          notes: string | null
          patient_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date?: string
          id?: string
          intensite?: number | null
          nom: string
          notes?: string | null
          patient_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date?: string
          id?: string
          intensite?: number | null
          nom?: string
          notes?: string | null
          patient_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "symptoms_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          assigned_to: string
          completed: boolean | null
          conversation_id: string
          created_at: string | null
          created_by: string
          description: string | null
          due_date: string | null
          id: string
          priority: number | null
          title: string
          updated_at: string | null
        }
        Insert: {
          assigned_to: string
          completed?: boolean | null
          conversation_id: string
          created_at?: string | null
          created_by: string
          description?: string | null
          due_date?: string | null
          id?: string
          priority?: number | null
          title: string
          updated_at?: string | null
        }
        Update: {
          assigned_to?: string
          completed?: boolean | null
          conversation_id?: string
          created_at?: string | null
          created_by?: string
          description?: string | null
          due_date?: string | null
          id?: string
          priority?: number | null
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_tasks_assigned_to"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_tasks_conversation"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_tasks_created_by"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      taxi_trajets: {
        Row: {
          arrivee: string
          arrivee_adresse: string | null
          chauffeur_nom: string | null
          chauffeur_note: number | null
          chauffeur_photo: string | null
          created_at: string | null
          date_trajet: string
          depart: string
          depart_adresse: string
          devise: string | null
          distance_km: number
          duree_minutes: number
          id: string
          prix: number
          status: string | null
          user_id: string
          vehicule_type: string | null
        }
        Insert: {
          arrivee: string
          arrivee_adresse?: string | null
          chauffeur_nom?: string | null
          chauffeur_note?: number | null
          chauffeur_photo?: string | null
          created_at?: string | null
          date_trajet: string
          depart: string
          depart_adresse: string
          devise?: string | null
          distance_km: number
          duree_minutes: number
          id?: string
          prix: number
          status?: string | null
          user_id: string
          vehicule_type?: string | null
        }
        Update: {
          arrivee?: string
          arrivee_adresse?: string | null
          chauffeur_nom?: string | null
          chauffeur_note?: number | null
          chauffeur_photo?: string | null
          created_at?: string | null
          date_trajet?: string
          depart?: string
          depart_adresse?: string
          devise?: string | null
          distance_km?: number
          duree_minutes?: number
          id?: string
          prix?: number
          status?: string | null
          user_id?: string
          vehicule_type?: string | null
        }
        Relationships: []
      }
      territoires: {
        Row: {
          id: string
          name: string
          province_id: string | null
        }
        Insert: {
          id?: string
          name: string
          province_id?: string | null
        }
        Update: {
          id?: string
          name?: string
          province_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "territoires_province_id_fkey"
            columns: ["province_id"]
            isOneToOne: false
            referencedRelation: "provinces"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_admin_access_requests: {
        Row: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          decided_role: string | null
          desired_role: string
          id: string
          message: string | null
          requester_id: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decided_role?: string | null
          desired_role?: string
          id?: string
          message?: string | null
          requester_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decided_role?: string | null
          desired_role?: string
          id?: string
          message?: string | null
          requester_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_admin_audit_logs: {
        Row: {
          action: string
          actor_role: string | null
          actor_user_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          metadata: Json
        }
        Insert: {
          action: string
          actor_role?: string | null
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: number
          metadata?: Json
        }
        Update: {
          action?: string
          actor_role?: string | null
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: number
          metadata?: Json
        }
        Relationships: []
      }
      thix_admin_memberships: {
        Row: {
          assigned_at: string | null
          email: string | null
          group_name: string | null
          role: string | null
          status: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          assigned_at?: string | null
          email?: string | null
          group_name?: string | null
          role?: string | null
          status?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          assigned_at?: string | null
          email?: string | null
          group_name?: string | null
          role?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      thix_call_signals: {
        Row: {
          call_id: string
          created_at: string
          from_user_id: string
          id: string
          payload: Json
          to_user_id: string
          type: string
        }
        Insert: {
          call_id: string
          created_at?: string
          from_user_id: string
          id?: string
          payload?: Json
          to_user_id: string
          type: string
        }
        Update: {
          call_id?: string
          created_at?: string
          from_user_id?: string
          id?: string
          payload?: Json
          to_user_id?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_call_signals_call_id_fkey"
            columns: ["call_id"]
            isOneToOne: false
            referencedRelation: "call_history"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_chat_chats: {
        Row: {
          created_at: string | null
          direct_key: string | null
          id: string
          is_read: boolean | null
          message_content: string
          participants: Json | null
          receiver_id: string | null
          sender_id: string | null
          title: string | null
          type: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          direct_key?: string | null
          id?: string
          is_read?: boolean | null
          message_content: string
          participants?: Json | null
          receiver_id?: string | null
          sender_id?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          direct_key?: string | null
          id?: string
          is_read?: boolean | null
          message_content?: string
          participants?: Json | null
          receiver_id?: string | null
          sender_id?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      thix_chat_messages: {
        Row: {
          chat_id: string
          content: string | null
          created_at: string | null
          id: string
          media_url: string | null
          metadata: Json | null
          pinned: boolean | null
          sender_id: string
          status: string | null
          type: string | null
        }
        Insert: {
          chat_id: string
          content?: string | null
          created_at?: string | null
          id?: string
          media_url?: string | null
          metadata?: Json | null
          pinned?: boolean | null
          sender_id: string
          status?: string | null
          type?: string | null
        }
        Update: {
          chat_id?: string
          content?: string | null
          created_at?: string | null
          id?: string
          media_url?: string | null
          metadata?: Json | null
          pinned?: boolean | null
          sender_id?: string
          status?: string | null
          type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_chat_messages_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "thix_chat_chats"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_chat_reactions: {
        Row: {
          created_at: string | null
          message_id: string
          reaction: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          message_id: string
          reaction: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          message_id?: string
          reaction?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_chat_reactions_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "thix_chat_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_chat_reads: {
        Row: {
          chat_id: string
          read_at: string | null
          user_id: string
        }
        Insert: {
          chat_id: string
          read_at?: string | null
          user_id: string
        }
        Update: {
          chat_id?: string
          read_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_chat_reads_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "thix_chat_chats"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_companies: {
        Row: {
          about: string | null
          banner_url: string | null
          city: string | null
          country: string | null
          created_at: string
          id: string
          is_verified: boolean
          logo_url: string | null
          name: string
          updated_at: string
        }
        Insert: {
          about?: string | null
          banner_url?: string | null
          city?: string | null
          country?: string | null
          created_at?: string
          id?: string
          is_verified?: boolean
          logo_url?: string | null
          name: string
          updated_at?: string
        }
        Update: {
          about?: string | null
          banner_url?: string | null
          city?: string | null
          country?: string | null
          created_at?: string
          id?: string
          is_verified?: boolean
          logo_url?: string | null
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_emergency_admins: {
        Row: {
          created_at: string | null
          id: string
          name: string | null
          phone_number: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          name?: string | null
          phone_number?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string | null
          phone_number?: string | null
        }
        Relationships: []
      }
      thix_emergency_alerts: {
        Row: {
          audio_path: string | null
          created_at: string | null
          description: string | null
          id: string
          is_critical: boolean | null
          last_accuracy_m: number | null
          last_lat: number | null
          last_lng: number | null
          last_location_at: string | null
          latitude: number | null
          longitude: number | null
          message: string | null
          metadata: Json
          severity: string | null
          silent_mode: boolean | null
          status: string | null
          title: string | null
          type: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          audio_path?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_critical?: boolean | null
          last_accuracy_m?: number | null
          last_lat?: number | null
          last_lng?: number | null
          last_location_at?: string | null
          latitude?: number | null
          longitude?: number | null
          message?: string | null
          metadata?: Json
          severity?: string | null
          silent_mode?: boolean | null
          status?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          audio_path?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_critical?: boolean | null
          last_accuracy_m?: number | null
          last_lat?: number | null
          last_lng?: number | null
          last_location_at?: string | null
          latitude?: number | null
          longitude?: number | null
          message?: string | null
          metadata?: Json
          severity?: string | null
          silent_mode?: boolean | null
          status?: string | null
          title?: string | null
          type?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      thix_emergency_audit_logs: {
        Row: {
          action: string
          actor_user_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          metadata: Json
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: number
          metadata?: Json
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: number
          metadata?: Json
        }
        Relationships: []
      }
      thix_emergency_evidence: {
        Row: {
          alert_id: string
          created_at: string
          file_name: string | null
          file_size_bytes: number | null
          id: string
          kind: string
          mime_type: string | null
          storage_path: string
        }
        Insert: {
          alert_id: string
          created_at?: string
          file_name?: string | null
          file_size_bytes?: number | null
          id?: string
          kind: string
          mime_type?: string | null
          storage_path: string
        }
        Update: {
          alert_id?: string
          created_at?: string
          file_name?: string | null
          file_size_bytes?: number | null
          id?: string
          kind?: string
          mime_type?: string | null
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_emergency_evidence_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "thix_emergency_alerts"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_emergency_locations: {
        Row: {
          accuracy_m: number | null
          alert_id: string
          captured_at: string
          created_at: string
          heading_deg: number | null
          id: number
          lat: number
          lng: number
          speed_mps: number | null
        }
        Insert: {
          accuracy_m?: number | null
          alert_id: string
          captured_at?: string
          created_at?: string
          heading_deg?: number | null
          id?: number
          lat: number
          lng: number
          speed_mps?: number | null
        }
        Update: {
          accuracy_m?: number | null
          alert_id?: string
          captured_at?: string
          created_at?: string
          heading_deg?: number | null
          id?: number
          lat?: number
          lng?: number
          speed_mps?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_emergency_locations_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "thix_emergency_alerts"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_event_registrations: {
        Row: {
          created_at: string
          event_id: string
          id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          user_id: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_event_registrations_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "thix_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_event_registrations_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "thix_events_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_event_tickets: {
        Row: {
          attendee_email: string | null
          attendee_name: string | null
          created_at: string | null
          currency: string | null
          event_id: string
          id: string
          payment_method: string | null
          quantity: number | null
          status: string | null
          thix_code: string | null
          ticket_code: string
          total_price: number | null
          user_id: string
        }
        Insert: {
          attendee_email?: string | null
          attendee_name?: string | null
          created_at?: string | null
          currency?: string | null
          event_id: string
          id?: string
          payment_method?: string | null
          quantity?: number | null
          status?: string | null
          thix_code?: string | null
          ticket_code: string
          total_price?: number | null
          user_id: string
        }
        Update: {
          attendee_email?: string | null
          attendee_name?: string | null
          created_at?: string | null
          currency?: string | null
          event_id?: string
          id?: string
          payment_method?: string | null
          quantity?: number | null
          status?: string | null
          thix_code?: string | null
          ticket_code?: string
          total_price?: number | null
          user_id?: string
        }
        Relationships: []
      }
      thix_events: {
        Row: {
          agenda: Json
          category: string | null
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string
          description: string | null
          event_type: string
          highlights: Json
          id: string
          is_featured: boolean
          is_free: boolean
          max_participants: number
          meeting_link: string | null
          organizer: string
          place: string
          price: number | null
          quick_hook: string | null
          speakers: Json
          sponsors: Json
          starts_at: string
          status: string
          title: string
          updated_at: string
          virtual_link: string | null
        }
        Insert: {
          agenda?: Json
          category?: string | null
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          description?: string | null
          event_type?: string
          highlights?: Json
          id?: string
          is_featured?: boolean
          is_free?: boolean
          max_participants?: number
          meeting_link?: string | null
          organizer?: string
          place: string
          price?: number | null
          quick_hook?: string | null
          speakers?: Json
          sponsors?: Json
          starts_at: string
          status?: string
          title: string
          updated_at?: string
          virtual_link?: string | null
        }
        Update: {
          agenda?: Json
          category?: string | null
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          description?: string | null
          event_type?: string
          highlights?: Json
          id?: string
          is_featured?: boolean
          is_free?: boolean
          max_participants?: number
          meeting_link?: string | null
          organizer?: string
          place?: string
          price?: number | null
          quick_hook?: string | null
          speakers?: Json
          sponsors?: Json
          starts_at?: string
          status?: string
          title?: string
          updated_at?: string
          virtual_link?: string | null
        }
        Relationships: []
      }
      thix_info_news: {
        Row: {
          author_id: string | null
          body: string | null
          category: string | null
          content: string | null
          created_at: string | null
          description: string | null
          featured: boolean | null
          id: string
          image_url: string | null
          is_featured: boolean | null
          photo_url: string | null
          severity: string | null
          source: string | null
          subtitle: string | null
          summary: string | null
          thumbnail: string | null
          title: string
        }
        Insert: {
          author_id?: string | null
          body?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          description?: string | null
          featured?: boolean | null
          id?: string
          image_url?: string | null
          is_featured?: boolean | null
          photo_url?: string | null
          severity?: string | null
          source?: string | null
          subtitle?: string | null
          summary?: string | null
          thumbnail?: string | null
          title: string
        }
        Update: {
          author_id?: string | null
          body?: string | null
          category?: string | null
          content?: string | null
          created_at?: string | null
          description?: string | null
          featured?: boolean | null
          id?: string
          image_url?: string | null
          is_featured?: boolean | null
          photo_url?: string | null
          severity?: string | null
          source?: string | null
          subtitle?: string | null
          summary?: string | null
          thumbnail?: string | null
          title?: string
        }
        Relationships: []
      }
      thix_job_applications: {
        Row: {
          applicant_id: string | null
          cover_letter: string | null
          created_at: string | null
          id: string
          job_id: string | null
          recruiter_user_id: string | null
          resume_url: string | null
          status: string | null
          updated_at: string
        }
        Insert: {
          applicant_id?: string | null
          cover_letter?: string | null
          created_at?: string | null
          id?: string
          job_id?: string | null
          recruiter_user_id?: string | null
          resume_url?: string | null
          status?: string | null
          updated_at?: string
        }
        Update: {
          applicant_id?: string | null
          cover_letter?: string | null
          created_at?: string | null
          id?: string
          job_id?: string | null
          recruiter_user_id?: string | null
          resume_url?: string | null
          status?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_job_applications_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "thix_job_offers"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_job_interviews: {
        Row: {
          applicant_user_id: string
          application_id: string
          created_at: string
          id: string
          job_id: string
          meeting_url: string | null
          mode: string
          recruiter_user_id: string
          scheduled_at: string
          status: string
          updated_at: string
        }
        Insert: {
          applicant_user_id: string
          application_id: string
          created_at?: string
          id?: string
          job_id: string
          meeting_url?: string | null
          mode?: string
          recruiter_user_id: string
          scheduled_at: string
          status?: string
          updated_at?: string
        }
        Update: {
          applicant_user_id?: string
          application_id?: string
          created_at?: string
          id?: string
          job_id?: string
          meeting_url?: string | null
          mode?: string
          recruiter_user_id?: string
          scheduled_at?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_job_messages: {
        Row: {
          application_id: string | null
          body: string
          created_at: string
          id: string
          job_id: string
          receiver_user_id: string
          sender_user_id: string
          updated_at: string
        }
        Insert: {
          application_id?: string | null
          body: string
          created_at?: string
          id?: string
          job_id: string
          receiver_user_id: string
          sender_user_id: string
          updated_at?: string
        }
        Update: {
          application_id?: string | null
          body?: string
          created_at?: string
          id?: string
          job_id?: string
          receiver_user_id?: string
          sender_user_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_job_offers: {
        Row: {
          applicants_count: number
          benefits: string[] | null
          category: string | null
          company: string | null
          company_id: string | null
          company_logo_url: string | null
          created_at: string | null
          created_by: string | null
          deadline: string | null
          description: string | null
          experience_level: string | null
          id: string
          image_url: string | null
          industry: string | null
          is_featured: boolean
          is_verified_employer: boolean
          location: string | null
          posted_by: string | null
          recruiter_user_id: string | null
          reference_number: string | null
          requirements: string[] | null
          responsibilities: string[] | null
          salary_currency: string | null
          salary_max: number | null
          salary_min: number | null
          salary_range: string | null
          skills: string[] | null
          status: string | null
          tags: string[] | null
          title: string
          updated_at: string
          work_mode: string | null
        }
        Insert: {
          applicants_count?: number
          benefits?: string[] | null
          category?: string | null
          company?: string | null
          company_id?: string | null
          company_logo_url?: string | null
          created_at?: string | null
          created_by?: string | null
          deadline?: string | null
          description?: string | null
          experience_level?: string | null
          id?: string
          image_url?: string | null
          industry?: string | null
          is_featured?: boolean
          is_verified_employer?: boolean
          location?: string | null
          posted_by?: string | null
          recruiter_user_id?: string | null
          reference_number?: string | null
          requirements?: string[] | null
          responsibilities?: string[] | null
          salary_currency?: string | null
          salary_max?: number | null
          salary_min?: number | null
          salary_range?: string | null
          skills?: string[] | null
          status?: string | null
          tags?: string[] | null
          title: string
          updated_at?: string
          work_mode?: string | null
        }
        Update: {
          applicants_count?: number
          benefits?: string[] | null
          category?: string | null
          company?: string | null
          company_id?: string | null
          company_logo_url?: string | null
          created_at?: string | null
          created_by?: string | null
          deadline?: string | null
          description?: string | null
          experience_level?: string | null
          id?: string
          image_url?: string | null
          industry?: string | null
          is_featured?: boolean
          is_verified_employer?: boolean
          location?: string | null
          posted_by?: string | null
          recruiter_user_id?: string | null
          reference_number?: string | null
          requirements?: string[] | null
          responsibilities?: string[] | null
          salary_currency?: string | null
          salary_max?: number | null
          salary_min?: number | null
          salary_range?: string | null
          skills?: string[] | null
          status?: string | null
          tags?: string[] | null
          title?: string
          updated_at?: string
          work_mode?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_job_offers_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "thix_companies"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_job_saved: {
        Row: {
          created_at: string
          job_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          job_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          job_id?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_notifications: {
        Row: {
          body: string
          created_at: string
          data: Json
          id: string
          read: boolean
          title: string
          type: string
          user_id: string | null
        }
        Insert: {
          body?: string
          created_at?: string
          data?: Json
          id?: string
          read?: boolean
          title: string
          type?: string
          user_id?: string | null
        }
        Update: {
          body?: string
          created_at?: string
          data?: Json
          id?: string
          read?: boolean
          title?: string
          type?: string
          user_id?: string | null
        }
        Relationships: []
      }
      thix_official_courses: {
        Row: {
          cover_image_url: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          id: string
          instructor_name: string | null
          price: number | null
          title: string
        }
        Insert: {
          cover_image_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string
          instructor_name?: string | null
          price?: number | null
          title: string
        }
        Update: {
          cover_image_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string
          instructor_name?: string | null
          price?: number | null
          title?: string
        }
        Relationships: []
      }
      thix_opportunities: {
        Row: {
          apply_url: string | null
          category: string | null
          created_at: string
          created_by: string | null
          deadline: string | null
          deadline_label: string | null
          description: string | null
          eligibility: string[]
          id: string
          image_url: string | null
          location: string | null
          organizer: string | null
          reward_label: string | null
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          apply_url?: string | null
          category?: string | null
          created_at?: string
          created_by?: string | null
          deadline?: string | null
          deadline_label?: string | null
          description?: string | null
          eligibility?: string[]
          id?: string
          image_url?: string | null
          location?: string | null
          organizer?: string | null
          reward_label?: string | null
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          apply_url?: string | null
          category?: string | null
          created_at?: string
          created_by?: string | null
          deadline?: string | null
          deadline_label?: string | null
          description?: string | null
          eligibility?: string[]
          id?: string
          image_url?: string | null
          location?: string | null
          organizer?: string | null
          reward_label?: string | null
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_presence: {
        Row: {
          is_online: boolean
          last_seen_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          is_online?: boolean
          last_seen_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          is_online?: boolean
          last_seen_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_public_profiles: {
        Row: {
          account_status: string | null
          account_type: string | null
          avatar_url: string | null
          created_at: string | null
          display_name: string | null
          full_name: string | null
          id: string
          identity_preview_url: string | null
          identity_verified_at: string | null
          is_suspended: boolean
          is_verified: boolean | null
          last_update: string | null
          suspended_at: string | null
          suspended_by: string | null
          suspended_reason: string | null
          trust_level: string | null
          user_id: string | null
        }
        Insert: {
          account_status?: string | null
          account_type?: string | null
          avatar_url?: string | null
          created_at?: string | null
          display_name?: string | null
          full_name?: string | null
          id?: string
          identity_preview_url?: string | null
          identity_verified_at?: string | null
          is_suspended?: boolean
          is_verified?: boolean | null
          last_update?: string | null
          suspended_at?: string | null
          suspended_by?: string | null
          suspended_reason?: string | null
          trust_level?: string | null
          user_id?: string | null
        }
        Update: {
          account_status?: string | null
          account_type?: string | null
          avatar_url?: string | null
          created_at?: string | null
          display_name?: string | null
          full_name?: string | null
          id?: string
          identity_preview_url?: string | null
          identity_verified_at?: string | null
          is_suspended?: boolean
          is_verified?: boolean | null
          last_update?: string | null
          suspended_at?: string | null
          suspended_by?: string | null
          suspended_reason?: string | null
          trust_level?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      thix_push_tokens: {
        Row: {
          active: boolean
          created_at: string
          id: string
          last_seen_at: string | null
          platform: string
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          last_seen_at?: string | null
          platform: string
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          last_seen_at?: string | null
          platform?: string
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_safety_ads: {
        Row: {
          content: string | null
          created_at: string | null
          id: string
          image_url: string | null
          title: string | null
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          title?: string | null
        }
        Update: {
          content?: string | null
          created_at?: string | null
          id?: string
          image_url?: string | null
          title?: string | null
        }
        Relationships: []
      }
      thix_section_seen_state: {
        Row: {
          created_at: string
          seen_events_at: string | null
          seen_formations_at: string | null
          seen_info_at: string | null
          seen_jobs_at: string | null
          seen_messages_at: string | null
          seen_opportunities_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          seen_events_at?: string | null
          seen_formations_at?: string | null
          seen_info_at?: string | null
          seen_jobs_at?: string | null
          seen_messages_at?: string | null
          seen_opportunities_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          seen_events_at?: string | null
          seen_formations_at?: string | null
          seen_info_at?: string | null
          seen_jobs_at?: string | null
          seen_messages_at?: string | null
          seen_opportunities_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      thix_security_events: {
        Row: {
          created_at: string | null
          description: string | null
          event_type: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          event_type?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          event_type?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      thix_status_updates: {
        Row: {
          content: string | null
          created_at: string | null
          id: string
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          id?: string
        }
        Update: {
          content?: string | null
          created_at?: string | null
          id?: string
        }
        Relationships: []
      }
      thix_training_certificates: {
        Row: {
          created_at: string
          id: string
          issued_at: string
          revoked_at: string | null
          status: string
          training_id: string
          updated_at: string
          user_id: string
          verification_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          issued_at?: string
          revoked_at?: string | null
          status?: string
          training_id: string
          updated_at?: string
          user_id: string
          verification_id: string
        }
        Update: {
          created_at?: string
          id?: string
          issued_at?: string
          revoked_at?: string | null
          status?: string
          training_id?: string
          updated_at?: string
          user_id?: string
          verification_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_certificates_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_certificates_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_enrollments: {
        Row: {
          completed_at: string | null
          created_at: string
          id: string
          last_activity_at: string | null
          learning_minutes: number
          progress_percent: number
          status: string
          training_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          id?: string
          last_activity_at?: string | null
          learning_minutes?: number
          progress_percent?: number
          status?: string
          training_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          id?: string
          last_activity_at?: string | null
          learning_minutes?: number
          progress_percent?: number
          status?: string
          training_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_enrollments_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_enrollments_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_lesson_progress: {
        Row: {
          completed_at: string | null
          created_at: string
          enrollment_id: string
          id: string
          is_completed: boolean
          lesson_id: string
          quiz_score: number | null
          updated_at: string
          watched_duration_seconds: number
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          enrollment_id: string
          id?: string
          is_completed?: boolean
          lesson_id: string
          quiz_score?: number | null
          updated_at?: string
          watched_duration_seconds?: number
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          enrollment_id?: string
          id?: string
          is_completed?: boolean
          lesson_id?: string
          quiz_score?: number | null
          updated_at?: string
          watched_duration_seconds?: number
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_lesson_progress_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "thix_training_enrollments"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_lessons: {
        Row: {
          content: string | null
          created_at: string | null
          description: string | null
          id: string
          is_free_preview: boolean | null
          is_published: boolean | null
          lesson_order: number
          thumbnail_url: string | null
          title: string
          training_id: string
          updated_at: string | null
          video_bucket: string | null
          video_duration_seconds: number | null
          video_path: string | null
          video_url: string | null
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_free_preview?: boolean | null
          is_published?: boolean | null
          lesson_order: number
          thumbnail_url?: string | null
          title: string
          training_id: string
          updated_at?: string | null
          video_bucket?: string | null
          video_duration_seconds?: number | null
          video_path?: string | null
          video_url?: string | null
        }
        Update: {
          content?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_free_preview?: boolean | null
          is_published?: boolean | null
          lesson_order?: number
          thumbnail_url?: string | null
          title?: string
          training_id?: string
          updated_at?: string | null
          video_bucket?: string | null
          video_duration_seconds?: number | null
          video_path?: string | null
          video_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_lessons_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_lessons_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_training_reviews: {
        Row: {
          comment: string | null
          created_at: string
          id: string
          rating: number
          training_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string
          id?: string
          rating: number
          training_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string
          id?: string
          rating?: number
          training_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_training_reviews_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_training_reviews_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_trainings: {
        Row: {
          category: string
          certification_included: boolean
          completion_rate: number
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string
          currency: string
          delivery_mode: string
          description: string | null
          duration_minutes: number | null
          id: string
          institution_logo_url: string | null
          institution_name: string | null
          instructor_avatar_url: string | null
          instructor_name: string | null
          instructor_title: string | null
          is_featured: boolean
          is_free: boolean
          is_published: boolean
          language: string
          level: string
          price_amount: number | null
          rating: number
          requirements: string | null
          reviews_count: number
          skills: string[]
          start_date: string | null
          students_count: number
          tagline: string | null
          title: string
          updated_at: string
        }
        Insert: {
          category?: string
          certification_included?: boolean
          completion_rate?: number
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          currency?: string
          delivery_mode?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          institution_logo_url?: string | null
          institution_name?: string | null
          instructor_avatar_url?: string | null
          instructor_name?: string | null
          instructor_title?: string | null
          is_featured?: boolean
          is_free?: boolean
          is_published?: boolean
          language?: string
          level?: string
          price_amount?: number | null
          rating?: number
          requirements?: string | null
          reviews_count?: number
          skills?: string[]
          start_date?: string | null
          students_count?: number
          tagline?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          category?: string
          certification_included?: boolean
          completion_rate?: number
          cover_image_bucket?: string | null
          cover_image_path?: string | null
          created_at?: string
          currency?: string
          delivery_mode?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          institution_logo_url?: string | null
          institution_name?: string | null
          instructor_avatar_url?: string | null
          instructor_name?: string | null
          instructor_title?: string | null
          is_featured?: boolean
          is_free?: boolean
          is_published?: boolean
          language?: string
          level?: string
          price_amount?: number | null
          rating?: number
          requirements?: string | null
          reviews_count?: number
          skills?: string[]
          start_date?: string | null
          students_count?: number
          tagline?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      thix_typing: {
        Row: {
          conversation_id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          conversation_id: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          conversation_id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thix_typing_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "thix_chat_chats"
            referencedColumns: ["id"]
          },
        ]
      }
      thix_user_lesson_progress: {
        Row: {
          completed_at: string | null
          enrollment_id: string
          id: string
          is_completed: boolean | null
          last_position_seconds: number | null
          lesson_id: string
          updated_at: string | null
        }
        Insert: {
          completed_at?: string | null
          enrollment_id: string
          id?: string
          is_completed?: boolean | null
          last_position_seconds?: number | null
          lesson_id: string
          updated_at?: string | null
        }
        Update: {
          completed_at?: string | null
          enrollment_id?: string
          id?: string
          is_completed?: boolean | null
          last_position_seconds?: number | null
          lesson_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thix_user_lesson_progress_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "thix_training_enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thix_user_lesson_progress_lesson_id_fkey"
            columns: ["lesson_id"]
            isOneToOne: false
            referencedRelation: "thix_training_lessons"
            referencedColumns: ["id"]
          },
        ]
      }
      tm_accounts: {
        Row: {
          balance: number
          created_at: string
          currency: string
          id: string
          is_active: boolean
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          balance?: number
          created_at?: string
          currency?: string
          id?: string
          is_active?: boolean
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          balance?: number
          created_at?: string
          currency?: string
          id?: string
          is_active?: boolean
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tm_merchant_requests: {
        Row: {
          business_name: string
          business_type: string
          created_at: string
          id: string
          phone: string
          rejection_reason: string | null
          status: string
          tax_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          business_name: string
          business_type: string
          created_at?: string
          id?: string
          phone: string
          rejection_reason?: string | null
          status?: string
          tax_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          business_name?: string
          business_type?: string
          created_at?: string
          id?: string
          phone?: string
          rejection_reason?: string | null
          status?: string
          tax_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tm_nfc_cards: {
        Row: {
          card_id: string
          created_at: string
          id: string
          is_active: boolean
          last_used_at: string | null
          limit_without_pin: number
          pin_hash: string
          updated_at: string
          user_id: string
        }
        Insert: {
          card_id: string
          created_at?: string
          id?: string
          is_active?: boolean
          last_used_at?: string | null
          limit_without_pin?: number
          pin_hash: string
          updated_at?: string
          user_id: string
        }
        Update: {
          card_id?: string
          created_at?: string
          id?: string
          is_active?: boolean
          last_used_at?: string | null
          limit_without_pin?: number
          pin_hash?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tm_split_payments: {
        Row: {
          code: string
          created_at: string
          creator_id: string
          expires_at: string
          id: string
          is_completed: boolean
          merchant_id: string
          remaining_amount: number
          total_amount: number
        }
        Insert: {
          code: string
          created_at?: string
          creator_id: string
          expires_at: string
          id?: string
          is_completed?: boolean
          merchant_id: string
          remaining_amount: number
          total_amount: number
        }
        Update: {
          code?: string
          created_at?: string
          creator_id?: string
          expires_at?: string
          id?: string
          is_completed?: boolean
          merchant_id?: string
          remaining_amount?: number
          total_amount?: number
        }
        Relationships: []
      }
      tm_transactions: {
        Row: {
          amount: number
          created_at: string
          currency: string
          from_account_id: string | null
          id: string
          label: string | null
          metadata: Json | null
          reference: string | null
          status: string
          to_account_id: string | null
          type: string
        }
        Insert: {
          amount: number
          created_at?: string
          currency?: string
          from_account_id?: string | null
          id?: string
          label?: string | null
          metadata?: Json | null
          reference?: string | null
          status?: string
          to_account_id?: string | null
          type: string
        }
        Update: {
          amount?: number
          created_at?: string
          currency?: string
          from_account_id?: string | null
          id?: string
          label?: string | null
          metadata?: Json | null
          reference?: string | null
          status?: string
          to_account_id?: string | null
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "tm_transactions_from_account_id_fkey"
            columns: ["from_account_id"]
            isOneToOne: false
            referencedRelation: "tm_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tm_transactions_to_account_id_fkey"
            columns: ["to_account_id"]
            isOneToOne: false
            referencedRelation: "tm_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      tontine_members: {
        Row: {
          has_paid: boolean
          id: string
          joined_at: string
          tontine_id: string
          user_id: string
        }
        Insert: {
          has_paid?: boolean
          id?: string
          joined_at?: string
          tontine_id: string
          user_id: string
        }
        Update: {
          has_paid?: boolean
          id?: string
          joined_at?: string
          tontine_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tontine_members_tontine_id_fkey"
            columns: ["tontine_id"]
            isOneToOne: false
            referencedRelation: "tontines"
            referencedColumns: ["id"]
          },
        ]
      }
      tontine_payments: {
        Row: {
          amount: number
          created_at: string
          id: string
          member_id: string
          paid_at: string | null
          period: string
          status: string
          tontine_id: string
          transaction_id: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          member_id: string
          paid_at?: string | null
          period: string
          status?: string
          tontine_id: string
          transaction_id?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          member_id?: string
          paid_at?: string | null
          period?: string
          status?: string
          tontine_id?: string
          transaction_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tontine_payments_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "tontine_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tontine_payments_tontine_id_fkey"
            columns: ["tontine_id"]
            isOneToOne: false
            referencedRelation: "tontines"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tontine_payments_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      tontines: {
        Row: {
          contribution_amount: number
          created_at: string
          creator_id: string
          current_members: number
          description: string | null
          frequency: string
          id: string
          is_private: boolean
          max_members: number
          name: string
          next_payment_date: string | null
          start_date: string | null
          status: string
        }
        Insert: {
          contribution_amount: number
          created_at?: string
          creator_id: string
          current_members?: number
          description?: string | null
          frequency: string
          id?: string
          is_private?: boolean
          max_members: number
          name: string
          next_payment_date?: string | null
          start_date?: string | null
          status?: string
        }
        Update: {
          contribution_amount?: number
          created_at?: string
          creator_id?: string
          current_members?: number
          description?: string | null
          frequency?: string
          id?: string
          is_private?: boolean
          max_members?: number
          name?: string
          next_payment_date?: string | null
          start_date?: string | null
          status?: string
        }
        Relationships: []
      }
      training_courses: {
        Row: {
          category: string | null
          certification_included: boolean | null
          completion_rate: number | null
          cover_url: string | null
          created_at: string | null
          currency: string | null
          delivery_mode: string | null
          description: string | null
          id: string
          instructor_avatar: string | null
          instructor_name: string | null
          is_featured: boolean | null
          is_free: boolean | null
          is_published: boolean | null
          language: string | null
          level: string | null
          price_amount: number | null
          rating: number | null
          reviews_count: number | null
          students_count: number | null
          title: string
          updated_at: string | null
        }
        Insert: {
          category?: string | null
          certification_included?: boolean | null
          completion_rate?: number | null
          cover_url?: string | null
          created_at?: string | null
          currency?: string | null
          delivery_mode?: string | null
          description?: string | null
          id?: string
          instructor_avatar?: string | null
          instructor_name?: string | null
          is_featured?: boolean | null
          is_free?: boolean | null
          is_published?: boolean | null
          language?: string | null
          level?: string | null
          price_amount?: number | null
          rating?: number | null
          reviews_count?: number | null
          students_count?: number | null
          title: string
          updated_at?: string | null
        }
        Update: {
          category?: string | null
          certification_included?: boolean | null
          completion_rate?: number | null
          cover_url?: string | null
          created_at?: string | null
          currency?: string | null
          delivery_mode?: string | null
          description?: string | null
          id?: string
          instructor_avatar?: string | null
          instructor_name?: string | null
          is_featured?: boolean | null
          is_free?: boolean | null
          is_published?: boolean | null
          language?: string | null
          level?: string | null
          price_amount?: number | null
          rating?: number | null
          reviews_count?: number | null
          students_count?: number | null
          title?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      training_lessons: {
        Row: {
          content_type: string | null
          content_url: string | null
          created_at: string | null
          description: string | null
          duration_minutes: number | null
          id: string
          is_preview: boolean | null
          lesson_index: number
          module_id: string | null
          title: string
        }
        Insert: {
          content_type?: string | null
          content_url?: string | null
          created_at?: string | null
          description?: string | null
          duration_minutes?: number | null
          id?: string
          is_preview?: boolean | null
          lesson_index: number
          module_id?: string | null
          title: string
        }
        Update: {
          content_type?: string | null
          content_url?: string | null
          created_at?: string | null
          description?: string | null
          duration_minutes?: number | null
          id?: string
          is_preview?: boolean | null
          lesson_index?: number
          module_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_lessons_module_id_fkey"
            columns: ["module_id"]
            isOneToOne: false
            referencedRelation: "training_modules"
            referencedColumns: ["id"]
          },
        ]
      }
      training_modules: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          module_index: number
          title: string
          training_id: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          module_index: number
          title: string
          training_id?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          module_index?: number
          title?: string
          training_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "training_modules_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_courses"
            referencedColumns: ["id"]
          },
        ]
      }
      transactions: {
        Row: {
          amount: number
          completed_at: string | null
          created_at: string
          description: string | null
          id: string
          merchant: string | null
          metadata: Json | null
          reference: string | null
          status: string
          type: string
          user_id: string
        }
        Insert: {
          amount: number
          completed_at?: string | null
          created_at?: string
          description?: string | null
          id?: string
          merchant?: string | null
          metadata?: Json | null
          reference?: string | null
          status?: string
          type: string
          user_id: string
        }
        Update: {
          amount?: number
          completed_at?: string | null
          created_at?: string
          description?: string | null
          id?: string
          merchant?: string | null
          metadata?: Json | null
          reference?: string | null
          status?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      trusted_contacts: {
        Row: {
          contact_name: string | null
          created_at: string | null
          id: number
          phone: string | null
          user_id: string | null
        }
        Insert: {
          contact_name?: string | null
          created_at?: string | null
          id?: number
          phone?: string | null
          user_id?: string | null
        }
        Update: {
          contact_name?: string | null
          created_at?: string | null
          id?: number
          phone?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      user_blocks: {
        Row: {
          blocked_user_id: string
          created_at: string | null
          id: string
          user_id: string
        }
        Insert: {
          blocked_user_id: string
          created_at?: string | null
          id?: string
          user_id: string
        }
        Update: {
          blocked_user_id?: string
          created_at?: string | null
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_block_user"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_blocked_user"
            columns: ["blocked_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_devices: {
        Row: {
          fcm_token: string
          id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          fcm_token: string
          id?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          fcm_token?: string
          id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_devices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_education_records: {
        Row: {
          certificate_file_name: string | null
          certificate_path: string | null
          certified_by_thix: boolean | null
          created_at: string | null
          degree_title: string | null
          end_date: string | null
          field_of_study: string | null
          id: string
          school_name: string | null
          start_date: string | null
          user_id: string | null
          verification_status: string | null
          verified_at: string | null
        }
        Insert: {
          certificate_file_name?: string | null
          certificate_path?: string | null
          certified_by_thix?: boolean | null
          created_at?: string | null
          degree_title?: string | null
          end_date?: string | null
          field_of_study?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
          verification_status?: string | null
          verified_at?: string | null
        }
        Update: {
          certificate_file_name?: string | null
          certificate_path?: string | null
          certified_by_thix?: boolean | null
          created_at?: string | null
          degree_title?: string | null
          end_date?: string | null
          field_of_study?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
          verification_status?: string | null
          verified_at?: string | null
        }
        Relationships: []
      }
      user_educations: {
        Row: {
          certificate_url: string | null
          created_at: string | null
          duration: string | null
          end_date: string | null
          id: string
          organized_by: string | null
          skills: string[] | null
          start_date: string | null
          training_name: string | null
          user_id: string | null
        }
        Insert: {
          certificate_url?: string | null
          created_at?: string | null
          duration?: string | null
          end_date?: string | null
          id?: string
          organized_by?: string | null
          skills?: string[] | null
          start_date?: string | null
          training_name?: string | null
          user_id?: string | null
        }
        Update: {
          certificate_url?: string | null
          created_at?: string | null
          duration?: string | null
          end_date?: string | null
          id?: string
          organized_by?: string | null
          skills?: string[] | null
          start_date?: string | null
          training_name?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      user_enrollments: {
        Row: {
          completed_at: string | null
          current_lesson_id: string | null
          id: string
          last_accessed_at: string | null
          progress_percent: number | null
          started_at: string | null
          training_id: string | null
          user_id: string | null
        }
        Insert: {
          completed_at?: string | null
          current_lesson_id?: string | null
          id?: string
          last_accessed_at?: string | null
          progress_percent?: number | null
          started_at?: string | null
          training_id?: string | null
          user_id?: string | null
        }
        Update: {
          completed_at?: string | null
          current_lesson_id?: string | null
          id?: string
          last_accessed_at?: string | null
          progress_percent?: number | null
          started_at?: string | null
          training_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_enrollments_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_enrollments_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "thix_trainings_status"
            referencedColumns: ["id"]
          },
        ]
      }
      user_identity_details: {
        Row: {
          created_at: string | null
          document_type: string | null
          expiry_date: string | null
          id: string
          id_number: string | null
          issue_date: string | null
          issue_place: string | null
          recto_url: string | null
          selfie_url: string | null
          user_id: string | null
          verification_status: string | null
          verso_url: string | null
        }
        Insert: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number?: string | null
          issue_date?: string | null
          issue_place?: string | null
          recto_url?: string | null
          selfie_url?: string | null
          user_id?: string | null
          verification_status?: string | null
          verso_url?: string | null
        }
        Update: {
          created_at?: string | null
          document_type?: string | null
          expiry_date?: string | null
          id?: string
          id_number?: string | null
          issue_date?: string | null
          issue_place?: string | null
          recto_url?: string | null
          selfie_url?: string | null
          user_id?: string | null
          verification_status?: string | null
          verso_url?: string | null
        }
        Relationships: []
      }
      user_insurances: {
        Row: {
          created_at: string
          end_date: string
          id: string
          monthly_premium: number
          next_payment_date: string
          product_id: string
          start_date: string
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string
          end_date: string
          id?: string
          monthly_premium: number
          next_payment_date: string
          product_id: string
          start_date: string
          status?: string
          user_id: string
        }
        Update: {
          created_at?: string
          end_date?: string
          id?: string
          monthly_premium?: number
          next_payment_date?: string
          product_id?: string
          start_date?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_insurances_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "insurance_products"
            referencedColumns: ["id"]
          },
        ]
      }
      user_investments: {
        Row: {
          amount: number
          created_at: string
          current_value: number
          end_date: string | null
          id: string
          product_id: string
          start_date: string
          status: string
          transaction_id: string | null
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          current_value: number
          end_date?: string | null
          id?: string
          product_id: string
          start_date?: string
          status?: string
          transaction_id?: string | null
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          current_value?: number
          end_date?: string | null
          id?: string
          product_id?: string
          start_date?: string
          status?: string
          transaction_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_investments_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "investment_products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_investments_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      user_languages: {
        Row: {
          created_at: string | null
          id: string
          niveau: string | null
          nom_langue: string
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          niveau?: string | null
          nom_langue: string
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          niveau?: string | null
          nom_langue?: string
          user_id?: string | null
        }
        Relationships: []
      }
      user_push_tokens: {
        Row: {
          created_at: string
          device_info: Json | null
          id: string
          token: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          device_info?: Json | null
          id?: string
          token: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          device_info?: Json | null
          id?: string
          token?: string
          user_id?: string | null
        }
        Relationships: []
      }
      user_reports: {
        Row: {
          created_at: string | null
          id: string
          reason: string
          reported_user_id: string
          reporter_user_id: string
          reviewed_at: string | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          reason: string
          reported_user_id: string
          reporter_user_id: string
          reviewed_at?: string | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          reason?: string
          reported_user_id?: string
          reporter_user_id?: string
          reviewed_at?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_user_report_reported"
            columns: ["reported_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_user_report_reporter"
            columns: ["reporter_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          role_id: number
          user_id: string
        }
        Insert: {
          role_id: number
          user_id: string
        }
        Update: {
          role_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_school_history: {
        Row: {
          created_at: string | null
          degree_name: string | null
          diploma_url: string | null
          end_date: string | null
          id: string
          school_name: string | null
          start_date: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          degree_name?: string | null
          diploma_url?: string | null
          end_date?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          degree_name?: string | null
          diploma_url?: string | null
          end_date?: string | null
          id?: string
          school_name?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      user_status: {
        Row: {
          caption: string | null
          content_url: string | null
          created_at: string | null
          expires_at: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          caption?: string | null
          content_url?: string | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_status_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_work_experience: {
        Row: {
          company_name: string | null
          created_at: string | null
          end_date: string | null
          id: string
          job_title: string | null
          reference_letter_url: string | null
          start_date: string | null
          user_id: string | null
        }
        Insert: {
          company_name?: string | null
          created_at?: string | null
          end_date?: string | null
          id?: string
          job_title?: string | null
          reference_letter_url?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Update: {
          company_name?: string | null
          created_at?: string | null
          end_date?: string | null
          id?: string
          job_title?: string | null
          reference_letter_url?: string | null
          start_date?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      users: {
        Row: {
          auth_user_id: string | null
          avatar_url: string | null
          created_at: string | null
          display_name: string
          id: string
          last_seen: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          auth_user_id?: string | null
          avatar_url?: string | null
          created_at?: string | null
          display_name: string
          id: string
          last_seen?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          auth_user_id?: string | null
          avatar_url?: string | null
          created_at?: string | null
          display_name?: string
          id?: string
          last_seen?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      verification_requests: {
        Row: {
          created_at: string | null
          document_type: string | null
          document_url: string
          id: string
          rejection_reason: string | null
          reviewer_id: string | null
          status: string | null
          user_id: string | null
          verified_at: string | null
        }
        Insert: {
          created_at?: string | null
          document_type?: string | null
          document_url: string
          id?: string
          rejection_reason?: string | null
          reviewer_id?: string | null
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Update: {
          created_at?: string | null
          document_type?: string | null
          document_url?: string
          id?: string
          rejection_reason?: string | null
          reviewer_id?: string | null
          status?: string | null
          user_id?: string | null
          verified_at?: string | null
        }
        Relationships: []
      }
      villes: {
        Row: {
          id: string
          name: string
          province_id: string | null
        }
        Insert: {
          id?: string
          name: string
          province_id?: string | null
        }
        Update: {
          id?: string
          name?: string
          province_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "villes_province_id_fkey"
            columns: ["province_id"]
            isOneToOne: false
            referencedRelation: "provinces"
            referencedColumns: ["id"]
          },
        ]
      }
      virtual_cards: {
        Row: {
          card_holder_name: string
          card_number: string
          created_at: string
          cvv: string
          expiry_date: string
          id: string
          limit_amount: number
          spent_amount: number
          status: string
          user_id: string
        }
        Insert: {
          card_holder_name: string
          card_number: string
          created_at?: string
          cvv: string
          expiry_date: string
          id?: string
          limit_amount?: number
          spent_amount?: number
          status?: string
          user_id: string
        }
        Update: {
          card_holder_name?: string
          card_number?: string
          created_at?: string
          cvv?: string
          expiry_date?: string
          id?: string
          limit_amount?: number
          spent_amount?: number
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      vols: {
        Row: {
          arrivee: string
          bagage_cabine: string | null
          bagage_soute: string | null
          classe: string | null
          code_aeroport_arrivee: string
          code_aeroport_depart: string
          code_vol: string
          compagnie: string
          created_at: string | null
          depart: string
          devise: string | null
          duree_minutes: number
          escale_ville: string | null
          escales: number | null
          est_actif: boolean | null
          heure_arrivee: string
          heure_depart: string
          id: string
          image_url: string | null
          prix: number
          repas_inclus: boolean | null
        }
        Insert: {
          arrivee: string
          bagage_cabine?: string | null
          bagage_soute?: string | null
          classe?: string | null
          code_aeroport_arrivee: string
          code_aeroport_depart: string
          code_vol: string
          compagnie: string
          created_at?: string | null
          depart: string
          devise?: string | null
          duree_minutes: number
          escale_ville?: string | null
          escales?: number | null
          est_actif?: boolean | null
          heure_arrivee: string
          heure_depart: string
          id?: string
          image_url?: string | null
          prix: number
          repas_inclus?: boolean | null
        }
        Update: {
          arrivee?: string
          bagage_cabine?: string | null
          bagage_soute?: string | null
          classe?: string | null
          code_aeroport_arrivee?: string
          code_aeroport_depart?: string
          code_vol?: string
          compagnie?: string
          created_at?: string | null
          depart?: string
          devise?: string | null
          duree_minutes?: number
          escale_ville?: string | null
          escales?: number | null
          est_actif?: boolean | null
          heure_arrivee?: string
          heure_depart?: string
          id?: string
          image_url?: string | null
          prix?: number
          repas_inclus?: boolean | null
        }
        Relationships: []
      }
      wallet: {
        Row: {
          balance: number | null
          created_at: string | null
          id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          balance?: number | null
          created_at?: string | null
          id?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          balance?: number | null
          created_at?: string | null
          id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      wallets: {
        Row: {
          balance: number
          created_at: string
          currency: string
          id: string
          investment_balance: number
          is_active: boolean
          savings_balance: number
          updated_at: string
          user_id: string
        }
        Insert: {
          balance?: number
          created_at?: string
          currency?: string
          id?: string
          investment_balance?: number
          is_active?: boolean
          savings_balance?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          balance?: number
          created_at?: string
          currency?: string
          id?: string
          investment_balance?: number
          is_active?: boolean
          savings_balance?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      wishlist: {
        Row: {
          created_at: string | null
          id: string
          product_id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          product_id: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          product_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wishlist_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wishlist_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      geography_columns: {
        Row: {
          coord_dimension: number | null
          f_geography_column: unknown
          f_table_catalog: unknown
          f_table_name: unknown
          f_table_schema: unknown
          srid: number | null
          type: string | null
        }
        Relationships: []
      }
      geometry_columns: {
        Row: {
          coord_dimension: number | null
          f_geometry_column: unknown
          f_table_catalog: string | null
          f_table_name: unknown
          f_table_schema: unknown
          srid: number | null
          type: string | null
        }
        Insert: {
          coord_dimension?: number | null
          f_geometry_column?: unknown
          f_table_catalog?: string | null
          f_table_name?: unknown
          f_table_schema?: unknown
          srid?: number | null
          type?: string | null
        }
        Update: {
          coord_dimension?: number | null
          f_geometry_column?: unknown
          f_table_catalog?: string | null
          f_table_name?: unknown
          f_table_schema?: unknown
          srid?: number | null
          type?: string | null
        }
        Relationships: []
      }
      monthly_transactions: {
        Row: {
          month: string | null
          total_expenses: number | null
          total_income: number | null
          transaction_count: number | null
          user_id: string | null
        }
        Relationships: []
      }
      thix_events_status: {
        Row: {
          availability_status: string | null
          category: string | null
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string | null
          event_type: string | null
          id: string | null
          is_featured: boolean | null
          is_free: boolean | null
          max_participants: number | null
          meeting_link: string | null
          organizer: string | null
          place: string | null
          places_remaining: number | null
          price: number | null
          quick_hook: string | null
          registrations_count: number | null
          starts_at: string | null
          status: string | null
          title: string | null
          updated_at: string | null
          virtual_link: string | null
        }
        Relationships: []
      }
      thix_trainings_status: {
        Row: {
          category: string | null
          certification_included: boolean | null
          completion_rate: number | null
          cover_image_bucket: string | null
          cover_image_path: string | null
          created_at: string | null
          currency: string | null
          current_students: number | null
          delivery_mode: string | null
          description: string | null
          duration_minutes: number | null
          id: string | null
          institution_logo_url: string | null
          institution_name: string | null
          instructor_avatar_url: string | null
          instructor_name: string | null
          instructor_title: string | null
          is_featured: boolean | null
          is_free: boolean | null
          is_published: boolean | null
          language: string | null
          level: string | null
          price_amount: number | null
          rating: number | null
          requirements: string | null
          reviews_count: number | null
          skills: string[] | null
          start_date: string | null
          students_count: number | null
          tagline: string | null
          title: string | null
          updated_at: string | null
        }
        Relationships: []
      }
      wallet_summary: {
        Row: {
          balance: number | null
          investment_balance: number | null
          savings_balance: number | null
          total_balance: number | null
          total_expenses: number | null
          total_income: number | null
          user_id: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      _postgis_deprecate: {
        Args: { newname: string; oldname: string; version: string }
        Returns: undefined
      }
      _postgis_index_extent: {
        Args: { col: string; tbl: unknown }
        Returns: unknown
      }
      _postgis_pgsql_version: { Args: never; Returns: string }
      _postgis_scripts_pgsql_version: { Args: never; Returns: string }
      _postgis_selectivity: {
        Args: { att_name: string; geom: unknown; mode?: string; tbl: unknown }
        Returns: number
      }
      _postgis_stats: {
        Args: { ""?: string; att_name: string; tbl: unknown }
        Returns: string
      }
      _st_3dintersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_containsproperly: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_coveredby:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_covers:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_crosses: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_dwithin: {
        Args: {
          geog1: unknown
          geog2: unknown
          tolerance: number
          use_spheroid?: boolean
        }
        Returns: boolean
      }
      _st_equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_intersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_linecrossingdirection: {
        Args: { line1: unknown; line2: unknown }
        Returns: number
      }
      _st_longestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      _st_maxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      _st_orderingequals: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_sortablehash: { Args: { geom: unknown }; Returns: number }
      _st_touches: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_voronoi: {
        Args: {
          clip?: unknown
          g1: unknown
          return_polygons?: boolean
          tolerance?: number
        }
        Returns: unknown
      }
      _st_within: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      addauth: { Args: { "": string }; Returns: boolean }
      addgeometrycolumn:
        | {
            Args: {
              catalog_name: string
              column_name: string
              new_dim: number
              new_srid_in: number
              new_type: string
              schema_name: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              new_dim: number
              new_srid: number
              new_type: string
              schema_name: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              new_dim: number
              new_srid: number
              new_type: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
      calculate_risk_score: { Args: { p_user_id: string }; Returns: number }
      check_expired_trials: { Args: never; Returns: undefined }
      credit_wallet: {
        Args: {
          amount: number
          transaction_merchant: string
          transaction_reference: string
          transaction_type: string
          user_uuid: string
        }
        Returns: boolean
      }
      debit_wallet: {
        Args: {
          amount: number
          transaction_merchant: string
          transaction_reference: string
          transaction_type: string
          user_uuid: string
        }
        Returns: boolean
      }
      decrement_community_members: {
        Args: { community_id: string }
        Returns: undefined
      }
      decrement_post_likes: { Args: { post_id: string }; Returns: undefined }
      disablelongtransactions: { Args: never; Returns: string }
      dropgeometrycolumn:
        | {
            Args: {
              catalog_name: string
              column_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | { Args: { column_name: string; table_name: string }; Returns: string }
      dropgeometrytable:
        | {
            Args: {
              catalog_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | { Args: { schema_name: string; table_name: string }; Returns: string }
        | { Args: { table_name: string }; Returns: string }
      enablelongtransactions: { Args: never; Returns: string }
      equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      generate_thix_uid: { Args: { country_code: string }; Returns: string }
      geometry: { Args: { "": string }; Returns: unknown }
      geometry_above: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_below: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_cmp: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_contained_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_contains_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_distance_box: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_distance_centroid: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_eq: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_ge: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_gt: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_le: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_left: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_lt: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overabove: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overbelow: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overlaps_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overleft: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overright: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_right: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_same: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_same_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_within: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geomfromewkt: { Args: { "": string }; Returns: unknown }
      get_feed_posts: {
        Args: { post_limit?: number; target_user_id: string }
        Returns: {
          author_avatar: string
          author_name: string
          author_title: string
          comments_count: number
          content: string
          created_at: string
          id: string
          is_liked: boolean
          is_public: boolean
          likes_count: number
          media_type: string
          media_url: string
          user_id: string
        }[]
      }
      get_user_balance: { Args: { user_uuid: string }; Returns: number }
      get_user_role: { Args: never; Returns: string }
      gettransactionid: { Args: never; Returns: unknown }
      has_permission: { Args: { permission_name: string }; Returns: boolean }
      has_permission_advanced:
        | {
            Args: { permission_name: string; target_user?: string }
            Returns: boolean
          }
        | {
            Args: { required_permission: string; user_id: string }
            Returns: boolean
          }
      increment_article_views: {
        Args: { article_id: string }
        Returns: undefined
      }
      increment_community_members: {
        Args: { community_id: string }
        Returns: undefined
      }
      increment_community_posts: {
        Args: { community_id: string }
        Returns: undefined
      }
      increment_post_comments: { Args: { post_id: string }; Returns: undefined }
      increment_post_likes: { Args: { post_id: string }; Returns: undefined }
      increment_post_shares: { Args: { post_id: string }; Returns: undefined }
      increment_view_count: { Args: { media_id: string }; Returns: undefined }
      insert_audit_log: {
        Args: {
          p_action: string
          p_entity: string
          p_entity_id: string
          p_metadata: Json
        }
        Returns: undefined
      }
      is_admin: { Args: never; Returns: boolean }
      is_admin_or_super: { Args: never; Returns: boolean }
      is_super_admin: { Args: never; Returns: boolean }
      longtransactionsenabled: { Args: never; Returns: boolean }
      pgrst_schema_reload: { Args: never; Returns: undefined }
      populate_geometry_columns:
        | { Args: { tbl_oid: unknown; use_typmod?: boolean }; Returns: number }
        | { Args: { use_typmod?: boolean }; Returns: string }
      postgis_constraint_dims: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: number
      }
      postgis_constraint_srid: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: number
      }
      postgis_constraint_type: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: string
      }
      postgis_extensions_upgrade: { Args: never; Returns: string }
      postgis_full_version: { Args: never; Returns: string }
      postgis_geos_version: { Args: never; Returns: string }
      postgis_lib_build_date: { Args: never; Returns: string }
      postgis_lib_revision: { Args: never; Returns: string }
      postgis_lib_version: { Args: never; Returns: string }
      postgis_libjson_version: { Args: never; Returns: string }
      postgis_liblwgeom_version: { Args: never; Returns: string }
      postgis_libprotobuf_version: { Args: never; Returns: string }
      postgis_libxml_version: { Args: never; Returns: string }
      postgis_proj_version: { Args: never; Returns: string }
      postgis_scripts_build_date: { Args: never; Returns: string }
      postgis_scripts_installed: { Args: never; Returns: string }
      postgis_scripts_released: { Args: never; Returns: string }
      postgis_svn_version: { Args: never; Returns: string }
      postgis_type_name: {
        Args: {
          coord_dimension: number
          geomname: string
          use_new_name?: boolean
        }
        Returns: string
      }
      postgis_version: { Args: never; Returns: string }
      postgis_wagyu_version: { Args: never; Returns: string }
      search_suggestions: {
        Args: { limit_count?: number; search_query: string }
        Returns: {
          text: string
          type: string
        }[]
      }
      st_3dclosestpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3ddistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_3dintersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_3dlongestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3dmakebox: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3dmaxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_3dshortestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_addpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_angle:
        | { Args: { line1: unknown; line2: unknown }; Returns: number }
        | {
            Args: { pt1: unknown; pt2: unknown; pt3: unknown; pt4?: unknown }
            Returns: number
          }
      st_area:
        | { Args: { geog: unknown; use_spheroid?: boolean }; Returns: number }
        | { Args: { "": string }; Returns: number }
      st_asencodedpolyline: {
        Args: { geom: unknown; nprecision?: number }
        Returns: string
      }
      st_asewkt: { Args: { "": string }; Returns: string }
      st_asgeojson:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | {
            Args: {
              geom_column?: string
              maxdecimaldigits?: number
              pretty_bool?: boolean
              r: Record<string, unknown>
            }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_asgml:
        | {
            Args: {
              geog: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
            }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
        | {
            Args: {
              geog: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
              version: number
            }
            Returns: string
          }
        | {
            Args: {
              geom: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
              version: number
            }
            Returns: string
          }
      st_askml:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; nprefix?: string }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; nprefix?: string }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_aslatlontext: {
        Args: { geom: unknown; tmpl?: string }
        Returns: string
      }
      st_asmarc21: { Args: { format?: string; geom: unknown }; Returns: string }
      st_asmvtgeom: {
        Args: {
          bounds: unknown
          buffer?: number
          clip_geom?: boolean
          extent?: number
          geom: unknown
        }
        Returns: unknown
      }
      st_assvg:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; rel?: number }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; rel?: number }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_astext: { Args: { "": string }; Returns: string }
      st_astwkb:
        | {
            Args: {
              geom: unknown
              prec?: number
              prec_m?: number
              prec_z?: number
              with_boxes?: boolean
              with_sizes?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              geom: unknown[]
              ids: number[]
              prec?: number
              prec_m?: number
              prec_z?: number
              with_boxes?: boolean
              with_sizes?: boolean
            }
            Returns: string
          }
      st_asx3d: {
        Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
        Returns: string
      }
      st_azimuth:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: number }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
      st_boundingdiagonal: {
        Args: { fits?: boolean; geom: unknown }
        Returns: unknown
      }
      st_buffer:
        | {
            Args: { geom: unknown; options?: string; radius: number }
            Returns: unknown
          }
        | {
            Args: { geom: unknown; quadsegs: number; radius: number }
            Returns: unknown
          }
      st_centroid: { Args: { "": string }; Returns: unknown }
      st_clipbybox2d: {
        Args: { box: unknown; geom: unknown }
        Returns: unknown
      }
      st_closestpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_collect: { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
      st_concavehull: {
        Args: {
          param_allow_holes?: boolean
          param_geom: unknown
          param_pctconvex: number
        }
        Returns: unknown
      }
      st_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_containsproperly: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_coorddim: { Args: { geometry: unknown }; Returns: number }
      st_coveredby:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_covers:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_crosses: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_curvetoline: {
        Args: { flags?: number; geom: unknown; tol?: number; toltype?: number }
        Returns: unknown
      }
      st_delaunaytriangles: {
        Args: { flags?: number; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_difference: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_disjoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_distance:
        | {
            Args: { geog1: unknown; geog2: unknown; use_spheroid?: boolean }
            Returns: number
          }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
      st_distancesphere:
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
        | {
            Args: { geom1: unknown; geom2: unknown; radius: number }
            Returns: number
          }
      st_distancespheroid: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_dwithin: {
        Args: {
          geog1: unknown
          geog2: unknown
          tolerance: number
          use_spheroid?: boolean
        }
        Returns: boolean
      }
      st_equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_expand:
        | { Args: { box: unknown; dx: number; dy: number }; Returns: unknown }
        | {
            Args: { box: unknown; dx: number; dy: number; dz?: number }
            Returns: unknown
          }
        | {
            Args: {
              dm?: number
              dx: number
              dy: number
              dz?: number
              geom: unknown
            }
            Returns: unknown
          }
      st_force3d: { Args: { geom: unknown; zvalue?: number }; Returns: unknown }
      st_force3dm: {
        Args: { geom: unknown; mvalue?: number }
        Returns: unknown
      }
      st_force3dz: {
        Args: { geom: unknown; zvalue?: number }
        Returns: unknown
      }
      st_force4d: {
        Args: { geom: unknown; mvalue?: number; zvalue?: number }
        Returns: unknown
      }
      st_generatepoints:
        | { Args: { area: unknown; npoints: number }; Returns: unknown }
        | {
            Args: { area: unknown; npoints: number; seed: number }
            Returns: unknown
          }
      st_geogfromtext: { Args: { "": string }; Returns: unknown }
      st_geographyfromtext: { Args: { "": string }; Returns: unknown }
      st_geohash:
        | { Args: { geog: unknown; maxchars?: number }; Returns: string }
        | { Args: { geom: unknown; maxchars?: number }; Returns: string }
      st_geomcollfromtext: { Args: { "": string }; Returns: unknown }
      st_geometricmedian: {
        Args: {
          fail_if_not_converged?: boolean
          g: unknown
          max_iter?: number
          tolerance?: number
        }
        Returns: unknown
      }
      st_geometryfromtext: { Args: { "": string }; Returns: unknown }
      st_geomfromewkt: { Args: { "": string }; Returns: unknown }
      st_geomfromgeojson:
        | { Args: { "": Json }; Returns: unknown }
        | { Args: { "": Json }; Returns: unknown }
        | { Args: { "": string }; Returns: unknown }
      st_geomfromgml: { Args: { "": string }; Returns: unknown }
      st_geomfromkml: { Args: { "": string }; Returns: unknown }
      st_geomfrommarc21: { Args: { marc21xml: string }; Returns: unknown }
      st_geomfromtext: { Args: { "": string }; Returns: unknown }
      st_gmltosql: { Args: { "": string }; Returns: unknown }
      st_hasarc: { Args: { geometry: unknown }; Returns: boolean }
      st_hausdorffdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_hexagon: {
        Args: { cell_i: number; cell_j: number; origin?: unknown; size: number }
        Returns: unknown
      }
      st_hexagongrid: {
        Args: { bounds: unknown; size: number }
        Returns: Record<string, unknown>[]
      }
      st_interpolatepoint: {
        Args: { line: unknown; point: unknown }
        Returns: number
      }
      st_intersection: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_intersects:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_isvaliddetail: {
        Args: { flags?: number; geom: unknown }
        Returns: Database["public"]["CompositeTypes"]["valid_detail"]
        SetofOptions: {
          from: "*"
          to: "valid_detail"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      st_length:
        | { Args: { geog: unknown; use_spheroid?: boolean }; Returns: number }
        | { Args: { "": string }; Returns: number }
      st_letters: { Args: { font?: Json; letters: string }; Returns: unknown }
      st_linecrossingdirection: {
        Args: { line1: unknown; line2: unknown }
        Returns: number
      }
      st_linefromencodedpolyline: {
        Args: { nprecision?: number; txtin: string }
        Returns: unknown
      }
      st_linefromtext: { Args: { "": string }; Returns: unknown }
      st_linelocatepoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_linetocurve: { Args: { geometry: unknown }; Returns: unknown }
      st_locatealong: {
        Args: { geometry: unknown; leftrightoffset?: number; measure: number }
        Returns: unknown
      }
      st_locatebetween: {
        Args: {
          frommeasure: number
          geometry: unknown
          leftrightoffset?: number
          tomeasure: number
        }
        Returns: unknown
      }
      st_locatebetweenelevations: {
        Args: { fromelevation: number; geometry: unknown; toelevation: number }
        Returns: unknown
      }
      st_longestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makebox2d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makeline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makevalid: {
        Args: { geom: unknown; params: string }
        Returns: unknown
      }
      st_maxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_minimumboundingcircle: {
        Args: { inputgeom: unknown; segs_per_quarter?: number }
        Returns: unknown
      }
      st_mlinefromtext: { Args: { "": string }; Returns: unknown }
      st_mpointfromtext: { Args: { "": string }; Returns: unknown }
      st_mpolyfromtext: { Args: { "": string }; Returns: unknown }
      st_multilinestringfromtext: { Args: { "": string }; Returns: unknown }
      st_multipointfromtext: { Args: { "": string }; Returns: unknown }
      st_multipolygonfromtext: { Args: { "": string }; Returns: unknown }
      st_node: { Args: { g: unknown }; Returns: unknown }
      st_normalize: { Args: { geom: unknown }; Returns: unknown }
      st_offsetcurve: {
        Args: { distance: number; line: unknown; params?: string }
        Returns: unknown
      }
      st_orderingequals: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_perimeter: {
        Args: { geog: unknown; use_spheroid?: boolean }
        Returns: number
      }
      st_pointfromtext: { Args: { "": string }; Returns: unknown }
      st_pointm: {
        Args: {
          mcoordinate: number
          srid?: number
          xcoordinate: number
          ycoordinate: number
        }
        Returns: unknown
      }
      st_pointz: {
        Args: {
          srid?: number
          xcoordinate: number
          ycoordinate: number
          zcoordinate: number
        }
        Returns: unknown
      }
      st_pointzm: {
        Args: {
          mcoordinate: number
          srid?: number
          xcoordinate: number
          ycoordinate: number
          zcoordinate: number
        }
        Returns: unknown
      }
      st_polyfromtext: { Args: { "": string }; Returns: unknown }
      st_polygonfromtext: { Args: { "": string }; Returns: unknown }
      st_project: {
        Args: { azimuth: number; distance: number; geog: unknown }
        Returns: unknown
      }
      st_quantizecoordinates: {
        Args: {
          g: unknown
          prec_m?: number
          prec_x: number
          prec_y?: number
          prec_z?: number
        }
        Returns: unknown
      }
      st_reduceprecision: {
        Args: { geom: unknown; gridsize: number }
        Returns: unknown
      }
      st_relate: { Args: { geom1: unknown; geom2: unknown }; Returns: string }
      st_removerepeatedpoints: {
        Args: { geom: unknown; tolerance?: number }
        Returns: unknown
      }
      st_segmentize: {
        Args: { geog: unknown; max_segment_length: number }
        Returns: unknown
      }
      st_setsrid:
        | { Args: { geog: unknown; srid: number }; Returns: unknown }
        | { Args: { geom: unknown; srid: number }; Returns: unknown }
      st_sharedpaths: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_shortestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_simplifypolygonhull: {
        Args: { geom: unknown; is_outer?: boolean; vertex_fraction: number }
        Returns: unknown
      }
      st_split: { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
      st_square: {
        Args: { cell_i: number; cell_j: number; origin?: unknown; size: number }
        Returns: unknown
      }
      st_squaregrid: {
        Args: { bounds: unknown; size: number }
        Returns: Record<string, unknown>[]
      }
      st_srid:
        | { Args: { geog: unknown }; Returns: number }
        | { Args: { geom: unknown }; Returns: number }
      st_subdivide: {
        Args: { geom: unknown; gridsize?: number; maxvertices?: number }
        Returns: unknown[]
      }
      st_swapordinates: {
        Args: { geom: unknown; ords: unknown }
        Returns: unknown
      }
      st_symdifference: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_symmetricdifference: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_tileenvelope: {
        Args: {
          bounds?: unknown
          margin?: number
          x: number
          y: number
          zoom: number
        }
        Returns: unknown
      }
      st_touches: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_transform:
        | {
            Args: { from_proj: string; geom: unknown; to_proj: string }
            Returns: unknown
          }
        | {
            Args: { from_proj: string; geom: unknown; to_srid: number }
            Returns: unknown
          }
        | { Args: { geom: unknown; to_proj: string }; Returns: unknown }
      st_triangulatepolygon: { Args: { g1: unknown }; Returns: unknown }
      st_union:
        | { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
        | {
            Args: { geom1: unknown; geom2: unknown; gridsize: number }
            Returns: unknown
          }
      st_voronoilines: {
        Args: { extend_to?: unknown; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_voronoipolygons: {
        Args: { extend_to?: unknown; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_within: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_wkbtosql: { Args: { wkb: string }; Returns: unknown }
      st_wkttosql: { Args: { "": string }; Returns: unknown }
      st_wrapx: {
        Args: { geom: unknown; move: number; wrap: number }
        Returns: unknown
      }
      thix_check_admin: { Args: never; Returns: boolean }
      thix_is_admin:
        | { Args: never; Returns: boolean }
        | { Args: { min_level?: number }; Returns: boolean }
      thix_request_profile_access: {
        Args: {
          p_message?: string
          p_target_user_id: string
          p_thix_id?: string
        }
        Returns: string
      }
      thix_role_level: { Args: { role: string }; Returns: number }
      thix_set_access_request_status: {
        Args: { p_new_status: string; p_request_id: string }
        Returns: undefined
      }
      unlockrows: { Args: { "": string }; Returns: number }
      update_training_metrics: {
        Args: { p_training_id: string }
        Returns: undefined
      }
      updategeometrysrid: {
        Args: {
          catalogn_name: string
          column_name: string
          new_srid_in: number
          schema_name: string
          table_name: string
        }
        Returns: string
      }
    }
    Enums: {
      consultation_status_enum: "pending" | "completed" | "cancelled"
      exam_priority_enum: "normal" | "urgent" | "très urgent"
      exam_status_enum: "pending" | "in_progress" | "completed" | "cancelled"
      gender_enum: "Masculin" | "Féminin" | "Autre"
      status_enum: "active" | "inactive" | "pending" | "admitted"
      user_role:
        | "super_admin"
        | "admin"
        | "moderator"
        | "university_partner"
        | "recruiter"
        | "institution"
        | "support_agent"
      user_role_enum: "patient" | "doctor" | "pharmacy" | "admin"
    }
    CompositeTypes: {
      geometry_dump: {
        path: number[] | null
        geom: unknown
      }
      valid_detail: {
        valid: boolean | null
        reason: string | null
        location: unknown
      }
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      consultation_status_enum: ["pending", "completed", "cancelled"],
      exam_priority_enum: ["normal", "urgent", "très urgent"],
      exam_status_enum: ["pending", "in_progress", "completed", "cancelled"],
      gender_enum: ["Masculin", "Féminin", "Autre"],
      status_enum: ["active", "inactive", "pending", "admitted"],
      user_role: [
        "super_admin",
        "admin",
        "moderator",
        "university_partner",
        "recruiter",
        "institution",
        "support_agent",
      ],
      user_role_enum: ["patient", "doctor", "pharmacy", "admin"],
    },
  },
} as const
