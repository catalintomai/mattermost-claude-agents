# Confluence Pattern Reference

Reference data for the `confluence-alignment-reviewer` agent. Contains Confluence permission models and feature comparison checklists.

## Confluence Permission Model

### Space Permissions (analogous to Wiki/Channel)

| Permission | Description | MM Equivalent |
|------------|-------------|---------------|
| View Space | Can see the space exists | ReadChannelContent |
| Add Pages | Can create new pages | create_page |
| Delete Own | Can delete pages you created | delete_own_page |
| Delete | Can delete any page | delete_page |
| Edit | Can edit any page | edit_page |
| Add Attachments | Can upload files | (part of edit) |
| Add Comments | Can comment on pages | (part of read + create_post) |
| Delete Comments | Can delete any comment | (channel admin) |

### Page Restrictions (Per-Page ACL)

Confluence allows per-page restrictions:
- **View Restriction**: Only specific users/groups can view
- **Edit Restriction**: Only specific users/groups can edit

**MM Difference**: Mattermost uses channel-subservient model - no per-page ACL.

### Move Permissions in Confluence

**Moving within same space:**
- Requires Edit permission on the page

**Moving to different space:**
- Requires Delete/Remove permission in source space
- Requires Add Pages permission in target space

**Key Insight**: Cross-space move = Delete + Create, not just Edit

### Copy Permissions in Confluence

- Requires View permission on source
- Requires Add Pages permission in target space

### Comment Permissions in Confluence

- **Add Comment**: Anyone with View permission
- **Edit Comment**: Comment author only
- **Delete Comment**: Comment author or space admin
- **Resolve Comment**: Page author, comment author, or space admin

## Feature Comparison Checklist

For each area below, verify current MM behavior against the Confluence expectation. **Do not assume prior alignment status — always check the actual code.**

### Page Operations

| Operation | Confluence Permission |  Expected MM Permission |
|-----------|----------------------|------------------------|
| Create page | Add Pages | create_page |
| View page | View Space | read_page |
| Edit page | Edit | edit_page |
| Delete own page | Delete Own | delete_own_page |
| Delete any page | Delete | delete_page |
| Move within wiki | Edit | edit_page |
| Move to different wiki | Delete + Add | delete + create |
| Copy/Duplicate | View + Add | read + create |
| Restore version | Edit | edit_page |

### Hierarchy Operations

| Operation | Confluence Permission | Expected MM Permission |
|-----------|----------------------|------------------------|
| Create child page | Add Pages | create_page |
| Change parent (same space) | Edit on page | edit_page |
| Reorder siblings | Edit on parent | edit_page |
| View page tree | View Space | read_page |
| Expand/collapse | View Space | read_page |

### Comment Operations

| Operation | Confluence Permission | Expected MM Permission |
|-----------|----------------------|------------------------|
| Add inline comment | View | read_page + create_post |
| Reply to comment | View | read_page + create_post |
| Edit own comment | Author only | Author only |
| Delete own comment | Author | Author |
| Delete any comment | Space Admin | Channel Admin |
| Resolve comment | Author/PageOwner/Admin | Should be restrictive (see Known Deviations) |

### Draft Operations

| Operation | Confluence Permission | Expected MM Permission |
|-----------|----------------------|------------------------|
| Save draft | Edit | edit_page |
| View own drafts | Always | Always |
| View others' drafts | Never | Never |
| Publish draft (new) | Add Pages | create_page |
| Publish draft (existing) | Edit | edit_page |
| Discard draft | Always own | Always own |

### Version History

| Operation | Confluence Permission | Expected MM Permission |
|-----------|----------------------|------------------------|
| View history | View | read_page |
| View specific version | View | read_page |
| Compare versions | View | read_page |
| Restore version | Edit | edit_page |

## Known Deviations

### 1. No Per-Page ACL
**Confluence**: Can restrict view/edit on individual pages
**Mattermost**: Pages inherit channel permissions

**Recommendation**: Document as intentional simplification. Consider for future if needed.

### 2. No Space-Level Roles
**Confluence**: Has space admin, contributor, viewer roles
**Mattermost**: Uses channel roles (admin, user, guest)

**Recommendation**: Channel roles map well; document the mapping.

### 3. Comment Resolution Permissions
**Confluence**: Restrictive (author, page owner, space admin)
**Mattermost**: Permissive (anyone with create_post)

**Recommendation**: Align with Confluence - more restrictive is safer.

## Confluence Documentation Sources

1. **Space Permissions**: https://support.atlassian.com/confluence-cloud/docs/space-permissions-overview/
2. **Page Restrictions**: https://support.atlassian.com/confluence-cloud/docs/page-restrictions/
3. **Comments**: https://support.atlassian.com/confluence-cloud/docs/add-edit-and-delete-comments/
4. **Version History**: https://support.atlassian.com/confluence-cloud/docs/view-page-history/
