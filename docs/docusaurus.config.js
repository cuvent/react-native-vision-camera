const { themes } = require('prism-react-renderer')

module.exports = {
  title: 'VisionCamera',
  tagline: '📸 A powerful, high-performance React Native Camera library.',
  url: 'https://react-native-vision-camera.com',
  baseUrl: '/',
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'throw',
  favicon: '/favicon.ico',
  organizationName: 'mrousavy',
  projectName: 'react-native-vision-camera',
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  plugins: [
    ['vercel-analytics', { }],
  ],
  themeConfig: {
    /**
     * @type {import('@docusaurus/theme-mermaid').ThemeConfig['mermaid']}
     */
    mermaid: {
      options: {
        themeVariables: {
          git0: '#ffffff00',
          gitBranchLabel0: '#ffffff00',
          git1: '#ADD8E6',
          gitBranchLabel1: '#ffffff',
          git2: '#ACC8E6',
          gitBranchLabel2: '#ffffff',
          commitLabelColor: '#000000',
          commitLabelBackground: '#ffffff00',
          commitLabelFontSize: 24
        },
        fontSize: 40,
        gantt: {
          sectionFontSize: 40,
          fontSize: 40,
          barGap: 15,
          topPadding: 15,
          leftPadding: 400,
          barHeight: 90
        },
        gitGraph: {
          showBranches: true,
          rotateCommitLabel: false,
          parallelCommits: false,
          mainBranchName: 'Time'
        }
      },
    },
    algolia: {
      appId: 'NRK7PZXU6O',
      apiKey: '33d54e627c4587a6d8dbff79d5209e46',
      indexName: 'react-native-vision-camera2',
      contextualSearch: false
    },
    colorMode: {
      respectPrefersColorScheme: true
    },
    prism: {
      theme: themes.github,
      darkTheme: themes.palenight,
      additionalLanguages: [
        'bash',
        'json',
        'kotlin',
        'ruby',
        'cmake',
        'groovy',
        'java',
      ],
    },
    announcementBar: {
      id: 'shadowlens',
      content: '<b>ShadowLens is out!!! 🥳🥳</b> See VisionCamera in action: <a target="_blank" rel="noopener noreferrer" href="https://apps.apple.com/app/shadowlens/id6471849004">Download ShadowLens for iOS</a> or <a target="_blank" rel="noopener noreferrer" href="https://play.google.com/store/apps/details?id=com.mrousavy.shadowlens">Download ShadowLens for Android</a>',
      backgroundColor: '#e39600',
      textColor: '#ffffff',
      isCloseable: false,
    },
    navbar: {
      title: 'VisionCamera',
      logo: {
        alt: 'Logo',
        src: './android-chrome-192x192.png',
      },
      items: [
        {
          label: 'Guides',
          to: 'docs/guides',
          position: 'left',
        },
        {
          to: 'docs/api',
          label: 'API',
          position: 'left'
        },
        {
          href: 'https://github.com/mrousavy/react-native-vision-camera/tree/main/example',
          label: 'Example App',
          position: 'left'
        },
        {
          href: 'https://mrousavy.com/projects/shadowlens',
          label: 'ShadowLens',
          position: 'left'
        },
        {
          href: 'https://github.com/mrousavy/react-native-vision-camera',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Guides',
              to: 'docs/guides'
            },
            {
              label: 'API',
              to: 'docs/api',
            },
            {
              label: 'Example App',
              href: 'https://github.com/mrousavy/react-native-vision-camera/tree/main/example',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Community Discord',
              href: 'https://margelo.com/discord',
            },
            {
              label: 'GitHub discussions',
              href: 'https://github.com/mrousavy/react-native-vision-camera/discussions',
            },
            {
              label: 'Twitter (@mrousavy)',
              href: 'https://twitter.com/mrousavy',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/mrousavy/react-native-vision-camera',
            },
            {
              label: 'Marc\'s Portfolio',
              href: 'https://mrousavy.com',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Marc Rousavy`,
    },
    image: 'img/11.png',
    metadata: [
      {
        name: 'author',
        content: 'Marc Rousavy'
      },
      {
        name: 'keywords',
        content: 'react, native, camera, react-native, react-native-camera, photo, record, video, react-native-vision-camera, VisionCamera, frame-processor, frame-processing, frame, qr, qr-code, barcode, scanning, detector, detection, documentation, coding, docs, guides, marc, rousavy, mrousavy'
      },
      {
        name: 'og:title',
        content: 'VisionCamera Documentation'
      },
      {
        name: 'og:type',
        content: 'application'
      },
      {
        name: 'og:description',
        content: 'A powerful, high-performance React Native Camera library.'
      },
      {
        name: 'og:image',
        content: '/img/11.png'
      },
    ],
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        sitemap: {
          changefreq: 'weekly',
          priority: 1.0,
          ignorePatterns: ['/tags/**'],
          filename: 'sitemap.xml',
        },
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/mrousavy/react-native-vision-camera/edit/main/docs/',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
        gtag: {
          trackingID: 'G-FX9Q0YKV7S',
          anonymizeIP: false,
        },
      },
    ],
  ],
  plugins: [
    [
      'docusaurus-plugin-typedoc',
      {
        name: 'VisionCamera',
        entryPoints: ['../package/src'],
        exclude: "../package/src/index.ts",
        tsconfig: '../package/tsconfig.json',
        watch: process.env.TYPEDOC_WATCH,
        excludePrivate: true,
        excludeProtected: true,
        excludeExternals: true,
        excludeInternal: true,
        readme: "none",
        sidebar: {
          indexLabel: 'Overview'
        }
      },
    ],
  ],
  headTags: [
    {
      tagName: "link",
      attributes:
      {
        rel: "preconnect",
        href: "https://fonts.googleapis.com",
      }
    },
    {
      tagName: "link",
      attributes:
      {
        rel: "preconnect",
        href: "https://fonts.gstatic.com",
      }
    },
  ],
  stylesheets: [
    "https://fonts.googleapis.com/css2?family=Fira+Code:wght@500;700&display=swap"
  ]
}
