import { BrowserRouter } from 'react-router-dom';

import Header from '@Components/common/Header';
import Routes from '@Admin/Routes';
import ProUpgradeHeaderBanner from '@Components/pro/ProUpgradeHeaderBanner';

const ViewContainer = () => {
	return (
		<BrowserRouter>
			<ProUpgradeHeaderBanner />
			<Header />
			<Routes />
		</BrowserRouter>
	);
};

export default ViewContainer;
