import { mount } from 'enzyme'

import type { Props } from 'utilities/ReCaptchaV3'

import type { FunctionComponent } from 'react'

const ReCaptchaV3 = jest.requireActual('utilities/ReCaptchaV3').ReCaptchaV3 as FunctionComponent<Props>

describe('ReCaptchaV3', () => {
  it('should render itself correctly', () => {
    const wrapper = mount(<ReCaptchaV3 enabled={true} siteKey='fakeKey' action='test/action'/>)

    expect(wrapper.exists(ReCaptchaV3)).toEqual(true)
    expect(wrapper.find('input').prop('className')).toMatch('g-recaptcha')
  })

  it('should give the proper name to the input', () => {
    const action = 'test/action'
    const wrapper = mount(<ReCaptchaV3 enabled={true} siteKey='fakeKey' action={action}/>)

    expect(wrapper.find('input').prop('name')).toBe(`g-recaptcha-response-data[${action}]`)
  })

  it('should render empty when disabled', () => {
    const wrapper = mount(<ReCaptchaV3 enabled={false} siteKey='fakeKey' action='test/action'/>)

    expect(wrapper.find('input')).toHaveLength(0);
  })
})
