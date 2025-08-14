from unittest.mock import patch

import pytest
from update_da_dependencies import newest_version, update_da_dependency_versions


class TestNewestVersion:
    def test_basic_versions(self):
        versions = ["v3.0.12", "v2.0.6", "v3.0.4", "v2.0.3", "v3.0.21"]
        assert newest_version(versions) == "v3.0.21"

    def test_with_short_versions(self):
        versions = ["v3.0", "v3.0.1", "v2.9"]
        assert newest_version(versions) == "v3.0.1"

    def test_with_different_lengths(self):
        versions = ["v1", "v1.0.5", "v1.0.12", "v1.0"]
        assert newest_version(versions) == "v1.0.12"

    def test_single_version(self):
        versions = ["v4.5.6"]
        assert newest_version(versions) == "v4.5.6"

    def test_with_equal_versions(self):
        versions = ["v2.0.1", "v2.0.1"]
        assert newest_version(versions) == "v2.0.1"

    def test_empty_list(self):
        with pytest.raises(ValueError, match="empty"):
            newest_version([])


class TestUpdateIbmCatalog:

    def test_update_da_dependency_versions(self):
        ibm_catalog_json = {
            "products": [
                {
                    "name": "deploy-arch-ibm-secrets-manager",
                    "label": "Cloud automation for Secrets Manager",
                    "flavors": [
                        {
                            "label": "Fully configurable",
                            "name": "fully-configurable",
                            "index": 1,
                            "install_type": "fullstack",
                            "working_directory": "solutions/fully-configurable",
                            "dependencies": [
                                {
                                    "name": "deploy-arch-ibm-account-infra-base",
                                    "description": 'Advanced users can leverage cloud automation for account configuration to configure IBM Cloud account with a ready-made set of resource groups by default. When you enable the "with account settings" option, it also applies baseline security and governance settings.',
                                    "catalog_id": "7a4d68b4-cf8b-40cd-a3d1-f49aff526eb3",
                                    "flavors": [
                                        "resource-group-only",
                                        "resource-groups-with-account-settings",
                                    ],
                                    "default_flavor": "resource-group-only",
                                    "id": "63641cec-6093-4b4f-b7b0-98d2f4185cd6-global",
                                    "input_mapping": [
                                        {
                                            "dependency_input": "prefix",
                                            "version_input": "prefix",
                                            "reference_version": True,
                                        },
                                        {
                                            "dependency_output": "security_resource_group_name",
                                            "version_input": "existing_resource_group_name",
                                        },
                                    ],
                                    "optional": True,
                                    "on_by_default": False,
                                    "version": "v3.0.7",
                                }
                            ],
                            "dependency_version_2": True,
                            "terraform_version": "1.10.5",
                        },
                        {
                            "label": "Security-enforced",
                            "name": "security-enforced",
                            "index": 2,
                            "working_directory": "solutions/security-enforced",
                            "terraform_version": "1.10.5",
                        },
                    ],
                }
            ]
        }

        with patch("update_da_dependencies.CatalogManagementV1") as mock_service:
            mock_service.get_offering.return_value.get_result.return_value = {
                "id": "63641cec-6093-4b4f-b7b0-98d2f4185cd6-global",
                "label": "Cloud automation for account configuration",
                "name": "deploy-arch-ibm-account-infra-base",
                "short_description": "Creates and configures the base layer components of an IBM Cloud account",
                "kinds": [
                    {
                        "id": "65f6e7b2-bdef-4383-bf83-fa28abe18c53-global",
                        "versions": [
                            {
                                "id": "fa88886a-global",
                                "version": "v3.0.21",
                                "flavor": {
                                    "name": "standard",
                                    "label": "Standard",
                                    "index": 0,
                                },
                                "offering_id": "60d88e202c6640-global",
                                "catalog_id": "7a4d68b4",
                                "deprecated": False,
                                "state": {
                                    "current": "consumable",
                                    "current_entered": "2025-03-27T23:55:17.285930324Z",
                                    "previous": "validated",
                                },
                                "version_locator": "7a4d68b4.fa88886a-global",
                                "is_consumable": False,
                            },
                            {
                                "id": "406a1a37-2441-4ebf-a019-2af37a620118-global",
                                "version": "v3.0.20",
                                "flavor": {
                                    "name": "resource-group-only",
                                    "label": "Resource groups only",
                                    "index": 1,
                                },
                                "offering_id": "60d88e202c6640bf947bada562928167:o:63641cec-6093-4b4f-b7b0-98d2f4185cd6-global",
                                "catalog_id": "7a4d68b4-cf8b-40cd-a3d1-f49aff526eb3",
                                "deprecated": False,
                                "state": {
                                    "current": "consumable",
                                    "current_entered": "2025-05-06T08:51:33.563849038Z",
                                    "previous": "validated",
                                },
                                "version_locator": "7a4d68b4-cf8b-40cd-a3d1-f49aff526eb3.406a1a37-2441-4ebf-a019-2af37a620118-global",
                                "is_consumable": True,
                            },
                            {
                                "id": "41c5fa72-1d6f-420a-bb4e-b66be0cce433-global",
                                "version": "v3.0.0",
                                "flavor": {
                                    "name": "resource-group-only",
                                    "label": "Resource groups only",
                                    "index": 0,
                                },
                                "offering_id": "60d88e202c6640bf947bada562928167:o:63641cec-6093-4b4f-b7b0-98d2f4185cd6-global",
                                "catalog_id": "7a4d68b4-cf8b-40cd-a3d1-f49aff526eb3",
                                "deprecated": False,
                                "version_locator": "7a4d68b4-cf8b-40cd-a3d1-f49aff526eb3.41c5fa72-1d6f-420a-bb4e-b66be0cce433-global",
                                "is_consumable": True,
                            },
                        ],
                    }
                ],
                "provider": "IBM",
                "product_kind": "solution",
                "product_kind_label": "Deployable architecture",
            }

            updated_json = update_da_dependency_versions(mock_service, ibm_catalog_json)
            assert (
                updated_json["products"][0]["flavors"][0]["dependencies"][0]["version"]
                == "v3.0.20"
            )
