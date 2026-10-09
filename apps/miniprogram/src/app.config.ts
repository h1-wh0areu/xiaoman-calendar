export default defineAppConfig({
  pages: [
    'pages/home/index',
    'pages/timeline/index',
    'pages/signoff/index',
    'pages/family/index',
    'pages/clipboard/index',
    'pages/me/index',
  ],
  window: {
    navigationBarTitleText: '小满',
    navigationBarBackgroundColor: '#ffffff',
    navigationBarTextStyle: 'black',
    backgroundColor: '#ffffff',
  },
  tabBar: {
    color: '#8A8A8A',
    selectedColor: '#3B82F6',
    backgroundColor: '#ffffff',
    list: [
      { pagePath: 'pages/home/index', text: '日程' },
      { pagePath: 'pages/timeline/index', text: '时间线' },
      { pagePath: 'pages/family/index', text: '家庭' },
      { pagePath: 'pages/me/index', text: '我的' },
    ],
  },
});

function defineAppConfig<T>(c: T): T {
  return c;
}
