import { mine } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import hre, { ethers } from 'hardhat'

describe('ERC20HBase', () => {
  const supply = 1_000_000_000n // 1 billion tokens
  const decimals = 1_000_000_000_000_000_000n // 18 decimals

  async function deployFixtures() {
    const [owner, user1] = await hre.ethers.getSigners()

    const ERC20H = await ethers.getContractFactory('ERC20HBase')
    const ft = await ERC20H.deploy(owner, 'Test', 'TEST', supply * decimals, 10_000n)
    await ft.setUnlockCooldown(10n)

    const ERC20HMirror = await ethers.getContractFactory('ERC20HMirrorBase')
    const nft = await ERC20HMirror.deploy(owner, ft, '', '')

    await ft.setMirror(nft)

    // configure tiers
    await nft.addTiers([
      { units: BigInt(10_000), maxSupply: 5, uri: '' },
      { units: BigInt(1_000), maxSupply: 5, uri: '' },
    ])
    await nft.setActiveTiers([0, 1])

    return { owner, user1, ft, nft }
  }

  it('can mint 900 tokens at once', async () => {
    const [owner, user1] = await hre.ethers.getSigners()

    const ERC20H = await ethers.getContractFactory('ERC20HBase')
    const ft = await ERC20H.deploy(owner, 'Bald Bröthers', 'BALD', supply * decimals, 10_000n)
    const ERC20HMirror = await ethers.getContractFactory('ERC20HMirrorBase')
    const nft = await ERC20HMirror.deploy(owner, ft, '', '')
    await ft.setMirror(nft)

    // configure tiers
    await nft.addTiers([
      { units: BigInt(1), maxSupply: 10_000, uri: '' },
    ])
    await nft.setActiveTiers([0])

    await ft.lock(900n)

    expect(await nft.balanceOf(owner)).to.eq(900)
  })

  it('can transfer nfts', async () => {
    const { owner, user1, ft, nft } = await deployFixtures()

    await ft.lock(10_000n)

    expect(await nft.balanceOf(owner)).to.eq(1)
    expect(await nft.balanceOf(user1)).to.eq(0)

    await nft.safeTransferFrom(owner, user1, 0n)

    expect(await nft.balanceOf(owner)).to.eq(0)
    expect(await nft.balanceOf(user1)).to.eq(1)
  })

  it('it has a max supply', async () => {
    const { ft } = await deployFixtures()

    expect(await ft.maxSupply()).to.eq(supply * decimals)
  })

  it('it has overrides for name and symbol', async () => {
    const { owner, ft, nft: nftWithDefaults } = await deployFixtures()

    const customName = 'something custom'
    const customSymbol = 'CUSTOM'

    const ERC20HMirror = await ethers.getContractFactory('ERC20HMirrorBase')
    const nft = await ERC20HMirror.deploy(owner, ft, customName, customSymbol)

    expect(await nft.name()).to.eq(customName)
    expect(await nft.symbol()).to.eq(customSymbol)
    expect(await nftWithDefaults.name()).to.not.eq(customName)
    expect(await nftWithDefaults.symbol()).to.not.eq(customSymbol)
  })

  describe('burning', () => {
    it('can burn hybrid tokens', async () => {
      const { owner, ft } = await deployFixtures()

      expect(await ft.balanceOf(owner)).to.eq(supply * decimals)

      await ft.burn(decimals * 500_000_000n) // burn half of supply

      expect(await ft.totalSupply()).to.eq((supply * decimals) / 2n)
      expect(await ft.balanceOf(owner)).to.eq((supply * decimals) / 2n)
    })

    it('cannot burn locked tokens', async () => {
      const { owner, user1, ft } = await deployFixtures()

      expect(await ft.balanceOf(user1)).to.eq(0)

      await ft.connect(owner).transfer(user1, 1_500n)
      await ft.connect(user1).lock(1_500n)

      expect(await ft.balanceOf(user1)).to.eq(1_500n)
      const [locked, bonded, awaitingUnlock] = await ft.lockedBalancesOf(user1)
      expect(locked).to.eq(1_500n)
      expect(bonded).to.eq(1_000n)
      expect(awaitingUnlock).to.eq(0)

      await expect(ft.connect(user1).burn(600n)).to.be.revertedWithCustomError(ft, 'ERC20HInsufficientUnlockedBalance')

      await expect(ft.connect(user1).burn(100n)).to.be.revertedWithCustomError(ft, 'ERC20HInsufficientUnlockedBalance')

      await ft.connect(user1).unlock(100n)
      const [locked2, bonded2, awaitingUnlock2] = await ft.lockedBalancesOf(user1)
      expect(locked2).to.eq(1_500n)
      expect(bonded2).to.eq(1_000n)
      expect(awaitingUnlock2).to.eq(100n)

      await expect(ft.connect(user1).burn(100n)).to.be.revertedWithCustomError(ft, 'ERC20HInsufficientUnlockedBalance')
    })
  })

  describe('token uris', () => {
    it('no token uri for nonexistent token', async () => {
      const { owner, ft, nft } = await deployFixtures()

      await expect(nft.tokenURI(0n)).to.be.revertedWithCustomError(nft, 'ERC721NonexistentToken')
    })

    it('returns empty string for token uri', async () => {
      const { owner, ft, nft } = await deployFixtures()

      await ft.lock(10_000n)
      expect(await nft.ownerOf(0n)).to.eq(owner)

      expect(await nft.tokenURI(0n)).to.eq('')
    })

    it('returns non-iterative uri', async () => {
      const { owner, ft, nft } = await deployFixtures()

      const uri = 'https://example.com/asdf'

      await nft.setTierURI(0n, uri, '', false)

      await ft.lock(20_000n)
      expect(await nft.ownerOf(0n)).to.eq(owner)
      expect(await nft.ownerOf(1n)).to.eq(owner)

      expect(await nft.tokenURI(0n)).to.eq(uri)
      expect(await nft.tokenURI(1n)).to.eq(uri)
    })

    it('returns non-iterative uri with extension', async () => {
      const { owner, ft, nft } = await deployFixtures()

      const uri = 'https://example.com/asdf'
      const expectedUri = `${uri}.json`

      await nft.setTierURI(0n, uri, '.json', false)

      await ft.lock(20_000n)
      expect(await nft.ownerOf(0n)).to.eq(owner)
      expect(await nft.ownerOf(1n)).to.eq(owner)

      expect(await nft.tokenURI(0n)).to.eq(expectedUri)
      expect(await nft.tokenURI(1n)).to.eq(expectedUri)
    })

    it('returns iterative uri', async () => {
      const { owner, ft, nft } = await deployFixtures()

      const uri = 'https://example.com/asdf/'

      await nft.setTierURI(0n, uri, '', true)

      await ft.lock(20_000n)
      expect(await nft.ownerOf(0n)).to.eq(owner)
      expect(await nft.ownerOf(1n)).to.eq(owner)

      expect(await nft.tokenURI(0n)).to.eq(`${uri}0`)
      expect(await nft.tokenURI(1n)).to.eq(`${uri}1`)
    })

    it('returns iterative uri with extension', async () => {
      const { owner, ft, nft } = await deployFixtures()

      const uri = 'https://example.com/asdf/'

      await nft.setTierURI(0n, uri, '.json', true)

      await ft.lock(20_000n)
      expect(await nft.ownerOf(0n)).to.eq(owner)
      expect(await nft.ownerOf(1n)).to.eq(owner)

      expect(await nft.tokenURI(0n)).to.eq(`${uri}0.json`)
      expect(await nft.tokenURI(1n)).to.eq(`${uri}1.json`)
    })

    it('uses only token id suffix for iterative uris', async () => {
      const { owner, ft, nft } = await deployFixtures()

      const uri = 'https://example.com/asdf/'

      await nft.setTierURI(1n, uri, '.json', true)

      await ft.lock(60_000n)
      expect(await nft.ownerOf((1n << 32n) + 0n)).to.eq(owner)
      expect(await nft.ownerOf((1n << 32n) + 1n)).to.eq(owner)

      expect(await nft.tokenURI((1n << 32n) + 0n)).to.eq(`${uri}0.json`)
      expect(await nft.tokenURI((1n << 32n) + 1n)).to.eq(`${uri}1.json`)
    })

    it('updates already existing uri', async () => {
      const { owner, ft, nft } = await deployFixtures()

      const uri1 = 'https://example.com/asdf/'
      await nft.setTierURI(0n, uri1, '.json', true)

      await ft.lock(10_000n)

      expect(await nft.ownerOf(0n)).to.eq(owner)
      expect(await nft.tokenURI(0n)).to.eq(`${uri1}0.json`)

      const uri2 = 'ipfs://asdflkasjdfasefasadf/'
      await nft.setTierURI(0n, uri2, '.json', true)

      expect(await nft.tokenURI(0n)).to.eq(`${uri2}0.json`)
    })
  })
})
