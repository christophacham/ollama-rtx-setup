// @ts-check
import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Ollama RTX Setup',
  tagline: 'Local AI with NVIDIA GPUs - Setup, Tools, and Best Practices',
  favicon: 'img/favicon.ico',

  url: 'https://christophacham.github.io',
  baseUrl: '/ollama-rtx-setup/',

  organizationName: 'christophacham',
  projectName: 'ollama-rtx-setup',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          editUrl: 'https://github.com/christophacham/ollama-rtx-setup/tree/master/website/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: 'dark',
        disableSwitch: false,
        respectPrefersColorScheme: false,
      },
      navbar: {
        title: 'Ollama RTX Setup',
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'tutorialSidebar',
            position: 'left',
            label: 'Docs',
          },
          {
            href: 'https://github.com/christophacham/ollama-rtx-setup',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {
                label: 'Getting Started',
                to: '/docs/getting-started/quick-start',
              },
              {
                label: 'Model Selection Guide',
                to: '/docs/guides/model-selection',
              },
              {
                label: 'Architecture',
                to: '/docs/architecture/overview',
              },
            ],
          },
          {
            title: 'Tools',
            items: [
              {
                label: 'Ollama Manager',
                to: '/docs/tools/ollama-manager',
              },
              {
                label: 'Setup Scripts',
                to: '/docs/tools/setup-scripts',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/christophacham/ollama-rtx-setup',
              },
              {
                label: 'Ollama',
                href: 'https://ollama.ai',
              },
            ],
          },
        ],
        copyright: `Copyright ${new Date().getFullYear()} Christoph Acham. Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['powershell', 'bash', 'json', 'toml', 'yaml', 'go'],
      },
    }),
};

export default config;
