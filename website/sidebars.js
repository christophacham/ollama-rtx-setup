// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  tutorialSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/quick-start',
        'getting-started/installation',
        'getting-started/hardware',
      ],
    },
    {
      type: 'category',
      label: 'Guides',
      items: [
        'guides/model-selection',
        'guides/web-search',
        'guides/backup-restore',
        'guides/performance',
      ],
    },
    {
      type: 'category',
      label: 'Tools',
      items: [
        'tools/ollama-manager',
        'tools/setup-scripts',
        'tools/container-sync',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
        'architecture/network',
        'architecture/decisions',
      ],
    },
    {
      type: 'category',
      label: 'Troubleshooting',
      items: [
        'troubleshooting/podman-ollama',
        'troubleshooting/common-issues',
        'troubleshooting/debugging',
      ],
    },
  ],
};

export default sidebars;
