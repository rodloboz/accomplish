defmodule Accomplish.OAuthTest do
  use Accomplish.DataCase

  alias Accomplish.OAuth
  alias Accomplish.OAuth.{Application, AccessGrant, AccessToken, DeviceGrant, Identity}

  describe "oauth_applications" do
    setup do
      {:ok, application: oauth_application_fixture()}
    end

    test "list_applications/0 returns all applications", %{application: application} do
      assert OAuth.list_applications() == [application]
    end

    test "get_application!/1 returns the specified application", %{application: application} do
      assert OAuth.get_application!(application.id) == application
    end

    test "get_application!/1 raises error if the application does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        OAuth.get_application!(UUIDv7.generate())
      end
    end

    test "create_application/1 with valid data creates an application" do
      valid_attrs = %{
        name: "My App",
        redirect_uri: "https://example.com/callback",
        scopes: ["read:user", "write:user"],
        confidential: true
      }

      assert {:ok, %Application{} = application} = OAuth.create_application(valid_attrs)
      assert application.name == "My App"
      assert application.redirect_uri == "https://example.com/callback"
      assert application.scopes == ["read:user", "write:user"]
      assert application.confidential == true
    end

    test "create_application/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               OAuth.create_application(%{name: nil, redirect_uri: "invalid"})
    end

    test "update_application/2 updates an application with valid data", %{
      application: application
    } do
      update_attrs = %{name: "Updated App", scopes: ["read:repository"]}

      assert {:ok, %Application{} = updated_app} =
               OAuth.update_application(application, update_attrs)

      assert updated_app.name == "Updated App"
      assert updated_app.scopes == ["read:repository"]
    end

    test "update_application/2 with invalid data returns error changeset", %{
      application: application
    } do
      assert {:error, %Ecto.Changeset{}} =
               OAuth.update_application(application, %{redirect_uri: "invalid"})

      assert application == OAuth.get_application!(application.id)
    end

    test "delete_application/1 deletes an application", %{application: application} do
      assert {:ok, %Application{}} = OAuth.delete_application(application)
      assert_raise Ecto.NoResultsError, fn -> OAuth.get_application!(application.id) end
    end

    test "regenerate_application_secret/1 regenerates the application secret", %{
      application: application
    } do
      original_secret = application.secret

      assert {:ok, %Application{} = updated_application} =
               OAuth.regenerate_application_secret(application)

      assert updated_application.secret != original_secret
    end
  end

  describe "oauth_access_grants" do
    setup do
      application = oauth_application_fixture()
      user = user_fixture()

      %{application: application, user: user}
    end

    test "list_access_grants/1 returns all grants for a user", %{
      application: application,
      user: user
    } do
      access_grant = oauth_access_grant_fixture(user, application)

      assert OAuth.list_access_grants(user.id) == [access_grant]
    end

    test "get_access_grant_by_token/1 returns the grant by token", %{
      application: application,
      user: user
    } do
      access_grant = oauth_access_grant_fixture(user, application)

      assert OAuth.get_access_grant_by_token(access_grant.token) == access_grant
    end

    test "create_access_grant/1 with valid data creates a grant", %{
      application: application,
      user: user
    } do
      valid_attrs = %{
        token: Accomplish.OAuth.AccessGrant.generate_token(),
        expires_in: 3600,
        redirect_uri: "https://example.com/callback",
        scopes: ["read:user", "write:user"],
        application_id: oauth_application_fixture().id
      }

      assert {:ok, %AccessGrant{}} = OAuth.create_access_grant(user, application, valid_attrs)
    end

    test "create_access_grant/1 with invalid data returns error changeset", %{
      application: application,
      user: user
    } do
      invalid_attrs = %{token: nil, expires_in: -1, redirect_uri: nil, scopes: nil}

      assert {:error, %Ecto.Changeset{}} =
               OAuth.create_access_grant(user, application, invalid_attrs)
    end

    test "revoke_access_grant/1 revokes the grant", %{application: application, user: user} do
      access_grant = oauth_access_grant_fixture(user, application)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, %AccessGrant{revoked_at: ^now} = updated_access_grant} =
               OAuth.revoke_access_grant(access_grant)

      refute is_nil(updated_access_grant.revoked_at)
    end
  end

  describe "oauth_access_tokens" do
    setup do
      application = oauth_application_fixture()
      user = user_fixture()

      %{application: application, user: user}
    end

    test "list_access_tokens/1 returns all tokens for a user", %{
      application: application,
      user: user
    } do
      token = oauth_access_token_fixture(user, application)
      assert OAuth.list_access_tokens(user) == [token]
    end

    test "get_access_token_by_token/1 returns the token by its value", %{
      application: application,
      user: user
    } do
      token = oauth_access_token_fixture(user, application)
      assert OAuth.get_access_token_by_token(token.token) == token
    end

    test "create_access_token/3 creates a token without a user", %{application: application} do
      attrs = %{
        scopes: ["read:user"],
        expires_in: 3600
      }

      assert {:ok, %AccessToken{} = token} = OAuth.create_access_token(nil, application, attrs)

      assert token.user_id == nil
      assert token.application_id == application.id
    end

    test "create_access_token/3 creates a token with a user", %{
      application: application,
      user: user
    } do
      attrs = %{
        scopes: ["read:user"],
        expires_in: 3600
      }

      assert {:ok, %AccessToken{} = token} = OAuth.create_access_token(user, application, attrs)

      assert token.user_id == user.id
      assert token.application_id == application.id
    end

    test "create_access_token/3 with invalid data returns error changeset", %{
      application: application,
      user: user
    } do
      assert {:error, %Ecto.Changeset{}} =
               OAuth.create_access_token(user, application, %{token: "short"})
    end

    test "revoke_access_token/1 revokes the token", %{application: application, user: user} do
      token = oauth_access_token_fixture(user, application)
      assert {:ok, %AccessToken{revoked_at: revoked_at}} = OAuth.revoke_access_token(token)
      assert not is_nil(revoked_at)
    end
  end

  describe "oauth_device_grants" do
    setup do
      application = oauth_application_fixture()
      %{application: application}
    end

    test "create_device_grant/2 creates a device grant with valid data", %{
      application: application
    } do
      attrs =
        DeviceGrant.generate_tokens()
        |> Map.put_new(:expires_in, 3600)

      assert {:ok, %DeviceGrant{} = device_grant} =
               OAuth.create_device_grant(application, attrs)

      assert device_grant.device_code == attrs.device_code
      assert device_grant.user_code == attrs.user_code
      assert device_grant.expires_in == 3600
      assert device_grant.application_id == application.id
    end

    test "create_device_grant/2 with invalid data returns error changeset", %{
      application: application
    } do
      invalid_attrs = %{
        device_code: "invalid-code",
        user_code: "invalid-code",
        expires_in: -1
      }

      assert {:error, %Ecto.Changeset{}} =
               OAuth.create_device_grant(application, invalid_attrs)
    end

    test "get_device_grant_by_code/1 returns the device grant by code", %{
      application: application
    } do
      device_grant = oauth_device_grant_fixture(application)
      assert OAuth.get_device_grant_by_code(device_grant.device_code) == device_grant
    end

    test "get_device_grant_by_code/1 returns nil for an invalid code", %{application: application} do
      oauth_device_grant_fixture(application)
      assert OAuth.get_device_grant_by_code("invalid-code") == nil
    end

    test "update_device_grant/2 updates the device grant", %{application: application} do
      device_grant = oauth_device_grant_fixture(application)

      update_attrs = %{last_polling_at: DateTime.utc_now()}

      assert {:ok, %DeviceGrant{} = updated_device_grant} =
               OAuth.update_device_grant(device_grant, update_attrs)

      assert updated_device_grant.last_polling_at != nil
    end

    test "update_device_grant/2 with invalid data returns error changeset", %{
      application: application
    } do
      device_grant = oauth_device_grant_fixture(application)

      invalid_attrs = %{last_polling_at: "invalid-timestamp"}

      assert {:error, %Ecto.Changeset{}} =
               OAuth.update_device_grant(device_grant, invalid_attrs)
    end

    test "revoke_device_grant/1 revokes the device grant", %{application: application} do
      device_grant = oauth_device_grant_fixture(application)

      assert {:ok, %DeviceGrant{} = revoked_device_grant} =
               OAuth.revoke_device_grant(device_grant)

      assert revoked_device_grant.revoked_at != nil
      assert revoked_device_grant.expires_in == 0
    end

    test "revoke_device_grant/1 does not revoke an already revoked grant", %{
      application: application
    } do
      device_grant = oauth_device_grant_fixture(application)

      # Revoke the grant
      assert {:ok, %DeviceGrant{} = already_revoked} =
               OAuth.revoke_device_grant(device_grant)

      # Attempt to revoke again
      assert {:ok, %DeviceGrant{} = revoked_device_grant} =
               OAuth.revoke_device_grant(already_revoked)

      # Compare truncated timestamps
      assert DateTime.truncate(already_revoked.revoked_at, :second) ==
               DateTime.truncate(revoked_device_grant.revoked_at, :second)
    end
  end

  describe "oauth_identities" do
    test "list_identities/1 returns all oauth identities for a user" do
      user = user_fixture()
      oauth_identity = oauth_identity_fixture(%{user: user})

      assert OAuth.list_identities(user) == [oauth_identity]
    end

    test "get_oauth_identity/2 returns the oauth identity by provider and UID" do
      oauth_identity = oauth_identity_fixture()

      assert OAuth.get_oauth_identity(oauth_identity.provider, oauth_identity.uid) ==
               oauth_identity
    end

    test "get_oauth_identity_for_user/3 returns the oauth identity for a specific user" do
      user = user_fixture()
      other_user = user_fixture()
      oauth_identity = oauth_identity_fixture(%{user: user})

      assert OAuth.get_oauth_identity_for_user(
               user.id,
               oauth_identity.provider,
               oauth_identity.uid
             ) ==
               oauth_identity

      assert OAuth.get_oauth_identity_for_user(
               other_user.id,
               oauth_identity.provider,
               oauth_identity.uid
             ) ==
               nil
    end

    test "create_oauth_identity/1 with valid data creates an oauth identity" do
      user = user_fixture()

      valid_attrs = %{
        uid: "some uid",
        provider: "github",
        access_token: "some access_token",
        refresh_token: "some refresh_token",
        expires_at: ~U[2025-01-18 13:18:00Z],
        scopes: ["option1", "option2"],
        user_id: user.id
      }

      assert {:ok, %Identity{} = oauth_identity} = OAuth.create_oauth_identity(valid_attrs)
      assert oauth_identity.uid == "some uid"
      assert oauth_identity.provider == "github"
      assert oauth_identity.access_token == "some access_token"
      assert oauth_identity.refresh_token == "some refresh_token"
      assert oauth_identity.expires_at == ~U[2025-01-18 13:18:00Z]
      assert oauth_identity.scopes == ["option1", "option2"]
      assert oauth_identity.user_id == user.id
    end

    test "create_oauth_identity/1 with invalid data returns error changeset" do
      invalid_attrs = %{
        uid: nil,
        provider: nil,
        access_token: nil,
        refresh_token: nil,
        expires_at: nil,
        scopes: nil
      }

      assert {:error, %Ecto.Changeset{}} = OAuth.create_oauth_identity(invalid_attrs)
    end

    test "update_oauth_identity/2 with valid data updates the oauth identity" do
      oauth_identity = oauth_identity_fixture()

      update_attrs = %{
        uid: "some updated uid",
        access_token: "some updated access_token",
        refresh_token: "some updated refresh_token",
        expires_at: ~U[2025-01-19 13:18:00Z],
        scopes: ["option1"]
      }

      assert {:ok, %Identity{} = oauth_identity} =
               OAuth.update_oauth_identity(oauth_identity, update_attrs)

      assert oauth_identity.uid == "some updated uid"
      assert oauth_identity.access_token == "some updated access_token"
      assert oauth_identity.refresh_token == "some updated refresh_token"
      assert oauth_identity.expires_at == ~U[2025-01-19 13:18:00Z]
      assert oauth_identity.scopes == ["option1"]
    end

    test "update_oauth_identity/2 with invalid data returns error changeset" do
      oauth_identity = oauth_identity_fixture()

      invalid_attrs = %{
        uid: nil,
        provider: nil,
        access_token: nil,
        refresh_token: nil,
        expires_at: nil,
        scopes: nil
      }

      assert {:error, %Ecto.Changeset{}} =
               OAuth.update_oauth_identity(oauth_identity, invalid_attrs)

      assert oauth_identity ==
               OAuth.get_oauth_identity(oauth_identity.provider, oauth_identity.uid)
    end

    test "delete_oauth_identity/1 deletes the oauth identity" do
      oauth_identity = oauth_identity_fixture()
      assert {:ok, %Identity{}} = OAuth.delete_oauth_identity(oauth_identity)

      assert OAuth.get_oauth_identity(oauth_identity.provider, oauth_identity.uid) == nil
    end

    test "change_oauth_identity/1 returns an oauth identity changeset" do
      oauth_identity = oauth_identity_fixture()
      assert %Ecto.Changeset{} = OAuth.change_oauth_identity(oauth_identity)
    end

    test "link_identity_to_user/2 links an identity to a user" do
      user = user_fixture()
      oauth_identity = oauth_identity_fixture()

      assert {:ok, %Identity{} = updated_identity} =
               OAuth.link_identity_to_user(oauth_identity, user.id)

      assert updated_identity.user_id == user.id
    end
  end
end
