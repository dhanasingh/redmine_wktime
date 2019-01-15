# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkIssueAssignee < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :project
  belongs_to :issue
  belongs_to :user
  # attr_protected :others, :issue_id
  
  safe_attributes 'user_id'
end