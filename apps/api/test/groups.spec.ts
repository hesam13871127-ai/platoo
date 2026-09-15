import { UsersService } from '../src/users/users.service';

const memberships = (entries: Array<{ userId: string; role: string }>) => entries.map((entry) => ({ ...entry }));

describe('group membership management', () => {
  const setup = () => {
    const mysql = { query: jest.fn(), execute: jest.fn(async () => [{ affectedRows: 1 }]) };
    const service = new UsersService(mysql as any);
    return { mysql, service };
  };

  it('transfers ownership to the earliest admin when the owner leaves', async () => {
    const { mysql, service } = setup();
    mysql.query
      .mockResolvedValueOnce(memberships([{ userId: 'owner', role: 'owner' }, { userId: 'admin', role: 'admin' }, { userId: 'member', role: 'member' }]))
      .mockResolvedValueOnce([{ id: 'conversation' }])
      .mockResolvedValueOnce([{ userId: 'admin' }]);
    const result = await service.removeGroupMember('owner', 'group', 'owner');
    expect(result).toEqual({ success: true, disbanded: false });
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM group_members'), ['group', 'owner']);
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM conversation_members'), ['conversation', 'owner']);
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining(`SET role = 'owner'`), ['group', 'admin']);
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('SET owner_id = ?'), ['admin', 'group']);
  });

  it('disbands the group when the sole owner leaves', async () => {
    const { mysql, service } = setup();
    mysql.query
      .mockResolvedValueOnce(memberships([{ userId: 'owner', role: 'owner' }]))
      .mockResolvedValueOnce([{ id: 'conversation' }])
      .mockResolvedValueOnce([]);
    const result = await service.removeGroupMember('owner', 'group', 'owner');
    expect(result).toEqual({ success: true, disbanded: true });
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM user_groups'), ['group']);
  });

  it('lets admins remove members but not the owner or other admins', async () => {
    const { mysql, service } = setup();
    mysql.query
      .mockResolvedValueOnce(memberships([{ userId: 'admin', role: 'admin' }, { userId: 'member', role: 'member' }]))
      .mockResolvedValueOnce([]);
    await expect(service.removeGroupMember('admin', 'group', 'member')).resolves.toEqual({ success: true, disbanded: false });

    mysql.query.mockResolvedValueOnce(memberships([{ userId: 'admin', role: 'admin' }, { userId: 'owner', role: 'owner' }]));
    await expect(service.removeGroupMember('admin', 'group', 'owner')).rejects.toThrow('The group owner cannot be removed.');

    mysql.query.mockResolvedValueOnce(memberships([{ userId: 'admin', role: 'admin' }, { userId: 'admin-2', role: 'admin' }]));
    await expect(service.removeGroupMember('admin', 'group', 'admin-2')).rejects.toThrow('Only the owner can remove admins.');
  });

  it('rejects removals from non-admins and strangers', async () => {
    const { mysql, service } = setup();
    mysql.query.mockResolvedValueOnce(memberships([{ userId: 'member', role: 'member' }, { userId: 'other', role: 'member' }]));
    await expect(service.removeGroupMember('member', 'group', 'other')).rejects.toThrow('Only group admins can remove members.');

    mysql.query.mockResolvedValueOnce(memberships([{ userId: 'member', role: 'member' }]));
    await expect(service.removeGroupMember('member', 'group', 'stranger')).rejects.toThrow('Group membership not found.');
  });
});
