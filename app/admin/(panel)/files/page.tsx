import { PageTop } from "@/components/admin/PageTop";
import { MediaBrowser } from "@/components/admin/MediaBrowser";

export const metadata = { title: "Files" };
export const dynamic = "force-dynamic";

export default function FilesPage() {
  return (
    <>
      <PageTop title="Files" />
      <div className="a-content">
        <p className="a-desc">
          All photos and videos of the website in one place. Upload new files, copy a file&apos;s link, or delete files you don&apos;t need. Anywhere in the admin you can pick
          these files with <b>Choose from library</b>. “In use” means the file is shown somewhere on the website; “built-in” files are part of the website design.
        </p>
        <MediaBrowser mode="manage" />
      </div>
    </>
  );
}
